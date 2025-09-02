# Resource Management
The kernel manages various things on behalf of the userspace process, including files, sockets, IPC, devices, and more, which we call 'resources'. It is a good idea to have a unified way to handle such a range of resources to reduce complexity. Rather than exposing a separate set of syscalls for each resource, a generic abstractation can be introduced to simplify everything whilst also keeping it all centralised in one place. 

To do this, we implement an API where every resource can be opened, read from, written to, and closed using the same syscalls. Through this design, the kernel is kept small, whilst also letting new resources be added in the future with minimal change to both kernel and user code.

## Resource Abstractation
First, we can begin by defining a list of resource types:
```
typedef enum {
    FILE,
    MESSAGE_ENDPOINT,
    SHARED_MEM,
    // can extend later
} resource_type_t;
```

And then internally each resource is represented as a `resource_t` struct:
```
typedef struct {
    resource_type_t type;
    void* impl;
} resource_t;
```
_NOTE: The `impl` pointer is where resource-specific structs can be stored, such as file descriptor states, IPC queues, shared memory regions, etc._

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
Now each process has a resource table that is a map of integers, called handles, to the kernel resource objects. A handle is simply an identifier returned by the kernel when opening a resource that is later used by the user to inform what resource the operation should be performed upon. This way, the resource structure is not exposed to userspace. Because of this, the same handle number in different processes can refer to different resources. For example, in Unix, handles `0`, `1`, and `2` refer to stdio for each process. 

With this, we can also define a supporting function allowing the kernel to fetch a resource by handle:
```
resource_t* get_resource(process_t* proc, int handle) {

  // Invalid handle
  if (handle < 0 || handle >= MAX_HANDLES)
      return NULL;
  
    return proc->table[handle];
}
```


## Resource Lifecycle
A resource follows a rather straightforward lifecycle, regardless of its type: 
1. Firstly, a process acquires a handle by calling the `open_resource` system call.
2. While the handle is valid, the process can perform operations such as `read_resource` or `write_resource`.
3. Finally, when the process has finished using the resource, it calls `close_resource`, allowing the kernel to free any associated state.

Typically, a process should `close()` a resource once it is done using it. However, that is not always the case, as processes may exit without cleaning up properly, and thus it is up to the kernel to ensure resources aren't leaked.
```
for (int handle = 0; handle < MAX_RESOURCES; ++handle) {

  // Already closed or not used
  if(process->resource_table[handle] == 0)
    continue;

  close_resource(process, handle);
}
```


## Generic API
The generic interface for a resource consists of four primary functions: `open`, `read`, `write`, and `close`. These functions form the minimum required API that every resource type must support. To begin the implementation of this, our `resource_t` needs extending to support these operations:
```
typedef struct resource {
    // ...
    struct resource_ops* ops;
} resource_t;

typedef struct resource_ops {
    size_t (*read)(resource_t* res, void* buf, size_t len);
    size_t (*write)(resource_t* res, const void* buf, size_t len);
    void (*open)(resource_t* res);
    void (*close)(resource_t* res);
} resource_ops_t;
```
Operations are defined to be blocking by default, meaning that if a resource is not ready (for example, no data to read), the process is suspended until the operation can complete. Each resource type can override these generic operations to provide behavior specific to that resource. For example, a file resource can replace the write function with one that writes data to disk, while an IPC message resource could implement write to enqueue a message, allowing the same API call to behave differently depending on the resource.

It has been left as an exercise to the user to decide on how they want to handle extending this design for extra resource-specific functionality (ie, renaming a file). There are two (of many) ways to do this, each with its own trade-off. Firstly, a simpler design would be to just add more syscalls to handle this; however, this means the ABI grows as your kernel manages more resources. Another approach would be to pass an additional `size_t flags` parameter and let the resource-specific operation handle it, which would keep the original four operations but with added complexity. 

The dispatch code would be as follows:
```
size_t read_resource(process_t* proc, int handle, void* buf, size_t len) {
    resource_t* res = get_resource(proc, handle);
    if (!res || !res->ops->read)
      return -1;
    return res->ops->read(res, buf, len);
}

size_t write_resource(process_t* proc, int handle, const void* buf, size_t len) {
    resource_t* res = get_resource(proc, handle);
    if (!res || !res->ops->write)
      return -1;
    return res->ops->write(res, buf, len);
}

int open_resource(process_t* proc, resource_t* res) {
    for (int i = 0; i < MAX_HANDLES; i++) {
        if (proc->table[i] == NULL) {
            proc->table[i] = res;
            return i; // return handle
        }
    }
    return -1; // no free slot
}

void close_resource(process_t* proc, int handle) {
    resource_t* res = get_resource(proc, handle);
    if (!res)
      return;

    if (res->ops->close) res->ops->close(res); // call resource-specific close
    proc->table[handle] = NULL;
}
```

## Data Copying
Another thing left as an exercise to the user is to decide their method of copying data between userspace and the kernel.
One option is to use the userspace provided buffersm, which is efficient due to a single copy but does require sanitization of pointers and lengths to ensure safety. Some things to consider are other threads in the same address space modifying memory at the same address  Another option is to copy into a kernel buffer first, which simplifies the sanitization but has the added overhead and loss of performance. 
