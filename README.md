# class_database

A new Flutter project.

## Development Environment

For appwrite functions:

 - install appwrite CLI
 - run a function with `appwrite run functions`


## Design Decisions

RECORD ALL DESIGN DECISIONS HERE FOR FUTURE REFERENCE

### 1. Build a mobile app with flutter

I started with flutter to learn it.  A mobile application makes sense to have
good control over the voice recording.  Eventually we'll also want to support
offline usage.

### 2. Use Appwrite for authentication and database

Appwrite is a cloud database that is easy to set up and use. It is also free for small projects.
I could have used Firebase, but:

 - appwrite is open source
 - the flutter sdk is easier to set up, firebase relies on streams so it's a little more complicated to follow, although the advantage is that by default it supports some level of offline usage
 - wanted to try something different

### 3. Do not use third party packages for models or state management

I started with freezed and riverpod, but it added complexity.  Riverpod in
particular is quite opinionated about the way the application needs to be
structured, and sometimes at add with the way a "standard" flutter application
is written.  For now it is more interesting to learn the flutter basics and then
come back to these.

### 4. Do not share models between mobile app and backend

- even though they use the same database for now, this won't always be the case...
Once we add offline support things will diverge
- the models are used differently in the mobile app: we use different relations,
different properties.  Essentially the aggregates are not the same!  We don't
have truly separate bounded contexts because they use the same database (for
now).  But it's still cleaner to separate them.