# Resource Management

The kernel manages various things on behalf of the userspace process, including files, sockets, IPC, devices, and more, which we call _resources_. It is a good idea to have a unified way to handle such a range of resources to reduce complexity. Rather than exposing a separate set of syscalls for each resource, a generic abstractation can be introduced to simplify everything while also keeping it all centralized in one place. 

To do this, we implement an API where every resource can be opened, read from, written to, and closed using the same syscalls. Through this design, the kernel is kept small, whilst also letting new resources be added in the future with minimal change to both kernel and user code.

## Resource Abstractation

When talking about _resources_, we need a way to distinguish between the different types that the kernel may expect to provide to userspace. Each resource behaves differently internally, but from the view of the userspace process, everything should be accessible from the same set of syscalls. In order to achieve this, we define an enum of resource types to allow the kernel to tag each resource with its category. This way, when a system call is made, the kernel knows how to dispatch the request.

```
typedef enum {
    FILE,
    MESSAGE_ENDPOINT,
    SHARED_MEM,
    // can extend later
} resource_type_t;
```

In this example, `FILE` represents a file on the disk, `MESSAGE_ENDPOINT` is used for an IPC message queue, and `SHARED_MEM` for a shared memory region between processes. As the kernel grows this struct can be extended to support more resource types. 

Next, we need a generic representation of a resource inside the kernel. This can be defined by the `resource_t` struct:

```
typedef struct {
    resource_type_t type;
    void* impl;
} resource_t;
```

The `type` field tells the kernel what kind of resource it is, and the `impl` pointer allows the kernel to attach the resource-specific implementation of that resource. For example, a file's `impl` could point to a struct holding the file's offset and inode, or for shared memory, it could point to the physical address of that region. 

## Per Process Resource Table
With an abstract resource now defined, we can extend our previous definition of a process to include a **resource table**:

```
typedef struct {
size_t pid;
status_t process_status;

// Other fields

resource_t* resource_table[MAX_RESOURCES];
} process_t;
```

Now each process has a resource table that is a map of integers, called _handles_, to the kernel resource objects. A handle is simply an identifier returned by the kernel when opening a resource that is later used by the user to inform what resource the operation should be performed upon. This indirection is important because we do not want to expose any kernel pointers directly to a userspace process. Even if they cannot be used there, passing them could still create security or stability risks. This way, the resource structure is not exposed to userspace. Because of this, the same handle number in different processes can refer to different resources. For example, in Unix, handles `0`, `1`, and `2` refer to stdio for each process and are called "file descriptors". 

With this, we can also define a supporting function allowing the kernel to fetch a resource by handle:

```
resource_t* get_resource(process_t* proc, int handle) {

  // Invalid handle
  if (handle < 0 || handle >= MAX_HANDLES)
      return NULL;
  
    return proc->table[handle];
}
```

You would also want to implement two other functions: `int register_resource(process_t* proc, resource_t* rec)` that finds a free handle and stores the resource in the array and also `int remove_resource(process_t* proc, resource_t* rec)` that then marks that handle usable and frees the memory of that resource on clean up.


## Resource Lifecycle

A resource follows a rather straightforward lifecycle, regardless of its type: 
1. Firstly, a process acquires a handle by calling the `open_resource` system call.
2. While the handle is valid, the process can perform operations such as `read_resource` or `write_resource`.
3. Finally, when the process has finished using the resource, it calls `close_resource`, allowing the kernel to free any associated state.

Typically, a process should `close()` a resource once it is done using it. However, that is not always the case, as processes may exit without cleaning up properly, and thus it is up to the kernel to ensure resources aren't leaked. This could look like a loop through the process's resource table, calling `close_resource(process, handle);` for each open resource and letting the resource-specific `close()` function handle the work.  

## Generic API

Now that we have a way of representing resources, we need to define how a process can interact with them. Generally, having a different syscall for each resource type can lead to lots of repeated code segments and make the kernel interface harder to maintain and extend. Instead, the kernel can expose a minimal and uniform API that every resource supports. The generic interface for a resource consists of four primary functions: `open`, `read`, `write`, and `close`, and by restricting all resources to this same interface, we can reduce the complexity of both the kernel and userspace. To begin the implementation of this, our `resource_t` needs extending with a table of function pointers to support these operations. Each resource can then provide its own implementation of these four functions, whilst the generic interface remains the same.

```
typedef struct resource {
    resource_type_t type;
    void* impl;
    struct resource_functions_t* funcs;
} resource_t;

typedef struct resource_functions {
    size_t (*read)(resource_t* res, void* buf, size_t len);
    size_t (*write)(resource_t* res, const void* buf, size_t len);
    void (*open)(resource_t* res);
    void (*close)(resource_t* res);
} resource_functions_t;
```

Here, `funcs` is the dispatch table that tells the kernel how to perform each operation for each resource. With this, each function pointer can be set differently depending on whether the resource is a file, IPC endpoint, or something else. Operations are defined to be blocking by default, meaning that if a resource is not ready (for example, no data to read), the process is suspended until the operation can complete. Each resource type can override these generic operations to provide behavior specific to that resource.

It has been left as an exercise to the reader to decide on how they want to handle extending this design for extra resource-specific functionality (ie, renaming a file). A simpler design may be to just add more syscalls to handle this; however, this means the ABI grows as your kernel manages more resources.

On the kernel side of things, these syscalls can just act as dispatchers. For example, a `read_resource(...)` syscall would look up the process's resource table using the handle, retrieve the `resource_t`, and then forward the call to the correct, resource-specific, function:

```
size_t read_resource(process_t* proc, int handle, void* buf, size_t len) {
    resource_t* res = get_resource(proc, handle);

    // Invalid handle or unsupported operation
    if (!res || !res->funcs->read)
        return -1;

    return res->funcs->read(res, buf, len);
}
```

The other operations (`write`, `open`, `close`) would follow the same pattern above: get the resource from the handle and then call the appropriate function from the `funcs` table if supported. With this indirect approach, the kernel's syscall layer is kept minimal whilst allowing for each resource type to have its own specialised behavior.

## Data Copying

Another thing left as an exercise to the user is to decide their method of copying data between userspace and the kernel.
One option is to use the userspace provided buffers, which is efficient due to a single copy but does require sanitization of pointers and lengths to ensure safety. Some things to consider are other threads in the same address space modifying memory at the same address. Another option is to copy into a kernel buffer first, which simplifies the sanitization but has the added overhead and loss of performance. 

With using the user buffers, it's not necessarily a single copy, and you may be able to operate directly on the buffer (in which case it's zero-copy). Although, this can be dangerous as another user thread can write to, unmap, or remap the buffer while the kernel is operating on it. Holding a lock over the address space for that process throughout the entire duration of the resource operation is impractical, so the kernel must instead rely on fault handling. By faulting when the process tries to access the memory that the kernel is working with, it allows this behaviour to e caught and the kernel can try to abort or retry the operation safely. 
