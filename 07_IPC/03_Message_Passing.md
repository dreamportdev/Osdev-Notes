# IPC via Message Passing

Compared to shared memory, message passing is slightly more complex but does offer more features. It's comparable to networking where there is a receiver that must be ready for an incoming message, and a sender who creates the full message ahead of time, ready to send all at once.

Unlike shared memory, which can have many processes all communicating with one initial process (or even many), message passing is usually one-to-one.

Message passing also has more kernel overhead as the kernel must manually copy each message between processes, unlike shared memory where the kernel is only involved in creating or destroying shared memory. However the upside to the kernel being involved is that it can make decisions based on what's happening. If a process is waiting to receive a message, the kernel can dequeue that process from the scheduler until a message is sent, rather than scheduling the process only for it to spin wait.

The key concept to understand for message passing is that we now have two distinct parties: the sender and the receiver. The receiver must set up an *endpoint* that messages can be sent to ahead of time, and then wait for a message to appear there. An endpoint can be thought of as the mailbox out the front of your house. If you have no mailbox, they don't know where to deliver the mail.

More specifically, an endpoint is just a buffer with some global idenfier that we can look up. In unix systems these endpoints are typically managed by assigning them file descriptors, but we're going to use a linked list of structs to keep things simple. Each struct will represent an endpoint.

You may wish to use the VFS and file descriptors in your own design, or something completely different! Several of the ideas discussed in the previous chapter on shared memory apply here as well, like access control. We won't go over those again, but they're worth keeping in mind here.

## How It Works

After the initial setup, the implementation of message passing is similar to a relay race:

- Process 1 wants to receive incoming messages on an endpoint, so it calls a function telling the kernel it's ready. This function will only return once a flag has been set on the endpoint that a message is ready, and otherwise blocks the thread. We'll call this function `ipc_receive()`.
- Some time later process 2 wants to send a message, so it allocates a buffer and writes some data there.
- Process 2 now calls a function to tell the kernel it wants to send this buffer as a message to an endpoint. We'll call this function `ipc_send()`.
- Inside `ipc_send()` the buffer is copied into kernel memory. In our example we'll use the heap for this memory. We can then set a flag on the endpoint telling it that a message has been received.
- At this point `ipc_send()` can return, and process 2 can continue on as per normal.
- The next time process 1 runs, `ipc_receive()` will see that the flag has been set, and copy the message from the kernel buffer into a buffer for the program.
- The `ipc_receive()` function can also free the kernel buffer, before returning and letting process 1 continue as normal.

What we've described here is a double-copy implementation of message: because the data is first copied into the kernel, and then out of it. Hence we performed two copy operations.

## Initial Setup

As mentioned, there's some initial setup that goes into message passing: we need to create an endpoint. We're going to need a way to identify each endpoint, so we'll use a string. We'll also need a way to indicate when a message is available, the address of the buffer containing the message, and the length of the message buffer.

Since the struct representing the endpoint is going to be accessed by multiple proceses, we'll want a lock to protect the data from race conditions. We'll use the following struct to represent our endpoint:

```c
struct ipc_endpoint {
    char* name;
    void* msg_buffer;
    size_t msg_length;
    spinlock_t msg_lock;
    ipc_endpoint* next;
};
```

To save some space we'll use `NULL` as the message address to represent that there is no message available.

If you're wondering about the `next` field, that's because we're going to store these in a linked list. You'll want a variable to store the head of the list, and a lock to protect the list anytime it's modified.

```c
ipc_endpoint* first_endpoint = NULL;
spinlock_t endpoints_lock;
```

At this point we have all we need to implement a function to create a new endpoint. This doesn't need to be too complex, and just needs to create a new instance of our endpoint struct. Since we're using `NULL` to in the message buffer address to represent no message, we'll be sure to set that when creating a new endpoint. Also notice how we hold the lock when we're interacting with the list of endpoints, to prevent race conditions.

```c
void create_endpoint(const char* name) {
    ipc_endpoint* ep = malloc(sizeof(ipc_endpoint));
    ep->name = malloc(strlen(name) + 1);
    strcpy(ep->name, name);

    ep->msg_buffer = NULL;

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
}
```

As you can see creating a new endpoint is pretty simple, and most of the code in the example function is actually for managing the linked list.

Now our endpoint has been added to the list! As always we omitted checking for errors, and we didn't check if an endpoint with this name already exists. In the real world you'll want to handle this things.

### Removing An Endpoint
Removing an endpoint is also an important function to have. As this is a simple operation, implementing this is left as an exercise to the reader, but there are a few important things to consider:

- What happens if there unread messages when destroying an endpoint? How do you handle them?
- Who is allowed to remove an endpoint?

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
void* msg_copy = malloc(length);
memcpy(msg_copy, buffer, length);
```

Why do we make a copy of the original message? Well if we don't, the sending process has to keep the original message around until the receiver has processed it. We don't have a way for the receiver to communicate that it's finished reading the message. By making a copy, we can return from `ipc_send()` as soon as the message is sent, regardless of when the message is read. Now the sending process is free to do what it wants with the memory holding the original message as soon as `ipc_send()` has completed.

If you're performing this IPC as part of a system call from userspace, the memory containing the original message is unlikely to be mapped in the receiver's address space anyway, so we have to copy it into the kernel's address space, which is mapped in both processes.

All that's left is to tell the receiver it has a message available by placing the buffer address on the endpoint. Again, notice the use of the lock to prevent race conditions while we mess with the internals of the endpoint.

```c
acquire(&target->lock);
target->msg_buffer = msg_copy;
target->msg_length = length;
release(&target->lock);
```

After the lock on the endpoint is released, the message has been sent! Now it's up to the receiving thread to check the endpoint and set the buffer to NULL again.

### Multiple Messages

In theory this works, but we've overlooked one huge issue: what if there's already a message at the endpoint? You should handle this, and there's a couple of ways to go about it:

- Allow for multiple messages to be stored on an endpoint.
- Fail to send the message, instead returning an error code from `ipc_send()`.

The first option is recommended, as it's likely there will be some processes that handle a lot of messages. Implementing this is left as an exercise to the user, but a simple implemenation might use a struct to hold each message (the buffer address and length) and a next field. Yes, more linked lists!

Sending messages would now mean appending to the list instead of writing the buffer address as before.

## Receiving

We have seen how to send messages, now let's take a look at how to receive them. We're going to use a basic (and inefficient) example, but it shows how it could be done.

The theory behind this is simple: when we're in the receiving process, we allocate a buffer to hold the message, and copy the messge data stored at the endpoint into our local buffer. Now we can set the endpoint's `msg_buffer` field to `NULL` to indicate that there is no longer a message to be received. Note that setting the buffer to `NULL` is specific to our example code, and your implementation may be different.

As always, note the use of locks to prevent race conditions. The variable `endpoint` is assumed to be the endpoint we want to receive from.

```c
ipc_endpoint* endpoint;

acquire(&endpoint->lock);
void* local_copy = malloc(endpoint->msg_length);
memcpy(local_copy, endpoint->msg_data, endpoint->msg_length);

endpoint->msg_data = NULL;
endpoint->msg_length = 0;
release(&endpoint->lock);
```

At this point the endpoint is now ready to receive another message, and we've got a copy of the message in `local_copy`. You're successfully passed a message from one address space to another!

## Additional Notes

- We've described a double-copy implementation here, but you might want to try a single-copy implemenation. Single-copy implementations *can* be faster, but they require extra logic. For example the kernel will need to access the recipient's address space from the sender's address space, how do you manage this? If you have all of physical memory mapped somewhere (like an identity map, or direct map (HHDM)) you could use this, otherwise you will need some way to access this memory.
- A process waiting on an endpoint (to either send or receive a message) could be waiting quite a while in some circumstances. This is time the cpu could be doing work instead of blocking and spinning on a lock. A simple optimization would be to put the thread to sleep, and have it be woken up whenever the endpoint is updated: a new message is sent, or the current message is read.
- In this example we've allowed for messages of any size to be sent to an endpoint, but you may want to set a maximum message size for each endpoint when creating it. This makes it easier to receive messages as you know the maximum possible size the message can be, and can allocate a buffer without checking the size of the message. This might seem silly, but when receiving a message from userspace the program has to make a system call each time it wants the kernel to do something. Having a maximum size allows for one-less system call. Enforcing a maximum size for messages also has security benefits.

## Lock Free Designs

Implementing these is a beyond the scope of the book, but they are worth keeping in mind. The design we've used here has all processes fight over a single lock to add messages to the incoming message queue. You can imagine if this was the message queue for a busy program (like a window server), we would start to see some slowdowns. A lock-free design can allows for multiple processes to write to the queue without getting in the way of each other.

As you might expect, implementing this comes with some complexity - but it can be worth it. *Lockfree* queues are usually classified as either single/multiple *producer* (one or many writers) and single/multiple *consumer* (one or many readers). A *SPSC* (single producer, single consumer) queue is easy to implement but only allows for one process to read or write at the same time. An *MPMC* (multiple producer, multiple consumer) queue on the other hand allows for multiple readers and writers to happen all at the same time, without causing each other to block.

For something like our message queue above, we would want a *MPSC* (multiple producer, single consumer) queue - as there is only one process reading from the queue.
