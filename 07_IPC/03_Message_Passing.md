# IPC via Message Passing

Compared to shared memory, message passing is slightly more complex but does offer more features. It's comparable to networking where there is a receiver that must be ready for an incoming message, and a sender who creates the full message ahead of time, ready to send all at once.

Unlike shared memory, which can have many processes all communicating with one initial process (or even many), message passing is usually one-to-one.

Message passing also has more kernel overhead as the kernel must manually copy each message between processes, unlike shared memory where the kernel is only involved in creating or destroying shared memory. However the upside to the kernel being involved is that it can make decisions based on what's happening. If a process is waiting to receive a message, the kernel can dequeue that process from the scheduler until a message is sent, rather than scheduling the process only for it to spin wait.

The key concept to understand for message passing is that we now have two distinct parties: the sender and the receiver. The receiver must set up an *endpoint* that messages can be sent to ahead of time, and then wait for a message to appear there. An endpoint can be thought of as the mailbox out the front of your house. If you have no mailbox, they don't know where to deliver the mail.

More specifically, an endpoint is just a buffer with some global identifier that we can look up. In unix systems these endpoints are typically managed by assigning them file descriptors, but we're going to use a linked list of structs to keep things simple. Each struct will represent an endpoint.

You may wish to use the VFS and file descriptors in your own design, or something completely different! Several of the ideas discussed in the previous chapter on shared memory apply here as well, like access control. We won't go over those again, but they're worth keeping in mind here.

## How It Works

After the initial setup, the implementation of message passing is similar to a relay race:

- Process 1  wants to receive incoming messages on an endpoint, so it calls a function telling the kernel to create an endpoint in our IPC manager. This function will setup and return a block of (userspace) memory containing a message queue. We'll call this function `create_endpoint()`.
- Process 2 wants to send a message sometime later, so it allocates a buffer and writes some data there.
- Process 2 now calls a function to tell the kernel it wants to send this buffer as a message to an endpoint. We'll call this function `ipc_send()`.
- Inside `ipc_send()` the buffer is copied into kernel memory. In our example we'll use the heap for this memory. We can then switch to process 1's address space and copy the buffer on the heap into the queue.
- At this point `ipc_send()` can return, and process 2 can continue on as per normal.
- The message is now waiting at the end of the endpoint's message queue which processes 1 can do what it pleases with.


What we've described here is a double-copy implementation of message: because the data is first copied into the kernel, and then out of it. Hence we performed two copy operations.

## Initial Setup

As mentioned, there's some initial setup that goes into message passing: we need to create an endpoint. We're going to need a way to identify each endpoint, so we'll use a string. We'll also need a way to indicate when a message is available, the address of the buffer containing the message, and the length of the message buffer.

Since the struct representing the endpoint is going to be accessed by multiple processes, we'll want a lock to protect the data from race conditions. We'll use the following struct to represent our endpoint:

```c

typedef struct ipc_message{
    void* message_buffer;
    size_t message_size;
    uintptr_t next_message;
} ipc_message_t;

 typedef struct ipc_message_queue{
    ipc_message_t* messages;
} ipc_message_queue_t;

struct ipc_endpoint {
    char* name;
    ipc_message_queue_t* queue;
    uint64_t owner_pid;
    spinlock_t msg_lock;
    ipc_endpoint* next;
};
```

To save some space we'll use `NULL` as the `queue -> messages` address to represent that there is no message available.

If you're wondering about the `next` field, that's because we're going to store these in a linked list. You'll want a variable to store the head of the list, and a lock to protect the list anytime it's modified.

```c
ipc_endpoint* first_endpoint = NULL;
spinlock_t endpoints_lock;
```

At this point we have all we need to implement a function to create a new endpoint. This doesn't need to be too complex, and just needs to create a new instance of our endpoint struct. Since we're using `NULL` to in the message buffer address to represent no message, we'll be sure to set that when creating a new endpoint. Also notice how we hold the lock when we're interacting with the list of endpoints, to prevent race conditions. Note: `kmalloc()` assumes the use of kernel heap and `malloc()` assumes the active proccess' heap.

```c
void create_endpoint(const char* name) {

    // Create the end point
    ipc_endpoint* ep = kmalloc(sizeof(ipc_endpoint));
    ep->name = malloc(strlen(name) + 1);
    strcpy(ep->name, name);

    endpoint -> queue = (ipc_message_queue_t*)malloc(sizeof(ipc_message_queue_t));
    ep -> queue -> messages = NULL;

    owner_pid -> get_currently_executing_proc()

    //add endpoint to the end of the list
    acquire(&endpoints_lock);
    if (first_endpoint == NULL)
        first_endpoint = ep;
    else {
        ipc_endpoint* last = first_endpoint;
        while (last->next != NULL)
            last = last->next;
        last->next = ep;
    }
    release(&endpoints_lock);

    // This should go to the calling proc
    return endpoint -> queue;

}
```

As you can see creating a new endpoint is pretty simple, and most of the code in the example function is actually for managing the linked list.

Now our endpoint has been added to the list! As always we omitted checking for errors, and we didn't check if an endpoint with this name already exists. In the real world you'll want to handle this things.

### Removing An Endpoint
Removing an endpoint is also an important function to have. As this is a simple operation, implementing this is left as an exercise to the reader, but there are a few important things to consider:

- What happens if there unread messages when destroying an endpoint? How do you handle them?
- Who is allowed to remove an endpoint? (`owner_pid` would be useful here)

## Sending A Message

Now that we know where to send the data, let's look at the process for that.

When a process has a message it wants to send to the endpoint, it writes it into a buffer. We then tell the IPC manager that we want to send this buffer to this endpoint. This hints at what our function prototype might look like:

```c
void ipc_send(void* buffer, size_t length, const char* ep_name);
```

The `ep_name` argument is the name of the endpoint we want to send to in this case. Which leads nicely into the first thing we'll need to do: find an endpoint in the list with the matching name. This is a pretty standard algorithm, we just loop over each element comparing the endpoint's name with the one we're looking for.

```c
ipc_endpoint* target = first_endpoint;
//search the list for the endpoint we want
acquire(&endpoints_lock);
while (target != NULL) {
    if (strcmp(target->name, ep_name) == 0)
        break;
    target = target->next;
}

release(&endpoints_lock);
if (target == NULL)
    return;
```

You may want to return an error here if the endpoint couldn't be found, however in our case we're simply discarding the message.

Now we'll need to allocate a buffer to store a copy of the message in, and copy the original message into this buffer.

```c
void* kernel_copy = kmalloc(length);
memcpy(kernel_copy, buffer, length);
```

Why do we make a copy of the original message? Well if we don't, the sending process has to keep the original message around until the receiver has processed it. We don't have a way for the receiver to communicate that it's finished reading the message. By making a copy, we can return from `ipc_send()` as soon as the message is sent, regardless of when the message is read. Now the sending process is free to do what it wants with the memory holding the original message as soon as `ipc_send()` has completed.

If you're performing this IPC as part of a system call from userspace, the memory containing the original message is unlikely to be mapped in the receiver's address space anyway, so we have to copy it into the kernel's address space, which is mapped in both processes.

All that's left is to tell the receiver it has a message available by placing the buffer address on the endpoint. Again, notice the use of the lock to prevent race conditions while we mess with the internals of the endpoint.

```c
acquire(&target->lock);

load_address_space(target->owner_pid)

// Create the message
ipc_message_t* new_message = (ipc_message_t*)malloc(sizeof(ipc_message_t));
void* new_buffer = malloc(size);
new_message -> message_buffer = memcpy(new_buffer, kernel_copy, size);
new_message -> message_size = size;
new_message -> next_message = 0;

// Add  the message to the queue
// Left for the reader to do, trivial linked list appending

release(&target->lock);

kfree(kernel_copy)
restore_address_space()
```

After the lock on the endpoint is released, the message has been sent! Now it's up to the receiving thread to check the endpoint and remove the message from the list.

## Receiving

We have seen how to send messages, now let's take a look at how to receive them. We're going to use a basic example, but it shows how it could be done.

The theory behind this is simple: when we're in the receiving process, we have access to the message queue of the endpoint we created using `create_endpoint()` so we can just iterate through the linked list. It is assumed that `sys_create_endpoint` is your implementation of calling the kernel's `create_endpoint`.


```c

// Create a message endpoint
ipc_message_queue_t* message_queue = (ipc_message_queue_t *)sys_create_endpoint("name of endpoint");

// Handle the messages
ipc_message_t* message = nullptr
while(message != nullptr){

  do_what_you_want_with_it(message->message_buffer, message->message_size);

  // Remove from the list
  // Free the memory   

  // Move to the next message
  message_queue->messages = (ipc_message_t*)message->next_message;

}

```

You've successfully passed a message from one address space to another!

## Additional Notes

- We've described a double-copy implementation here, but you might want to try a single-copy implementation. Single-copy implementations *can* be faster, but they require extra logic. For example the kernel will need to access the recipient's address space from the sender's address space, how do you manage this? If you have all of physical memory mapped somewhere (like an identity map, or direct map (HHDM)) you could use this, otherwise you will need some way to access this memory.
- A process waiting on an endpoint (to either send or receive a message) could be waiting quite a while in some circumstances. This is time the cpu could be doing work instead of blocking and spinning on a lock. A simple optimization would be to put the thread to sleep, and have it be woken up whenever the endpoint is updated: a new message is sent, or the current message is read.
- In this example we've allowed for messages of any size to be sent to an endpoint, but you may want to set a maximum message size for each endpoint when creating it. This makes it easier to receive messages as you know the maximum possible size the message can be, and can allocate a buffer without checking the size of the message. This might seem silly, but when receiving a message from userspace the program has to make a system call each time it wants the kernel to do something. Having a maximum size allows for one-less system call. Enforcing a maximum size for messages also has security benefits.

## Lock Free Designs

Implementing these is a beyond the scope of the book, but they are worth keeping in mind. The design we've used here has all processes fight over a single lock to add messages to the incoming message queue. You can imagine if this was the message queue for a busy program (like a window server), we would start to see some slowdowns. A lock-free design can allows for multiple processes to write to the queue without getting in the way of each other.

As you might expect, implementing this comes with some complexity - but it can be worth it. *Lockfree* queues are usually classified as either single/multiple *producer* (one or many writers) and single/multiple *consumer* (one or many readers). A *SPSC* (single producer, single consumer) queue is easy to implement but only allows for one process to read or write at the same time. An *MPMC* (multiple producer, multiple consumer) queue on the other hand allows for multiple readers and writers to happen all at the same time, without causing each other to block.

For something like our message queue above, we would want a *MPSC* (multiple producer, single consumer) queue - as there is only one process reading from the queue.
