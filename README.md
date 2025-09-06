# Grade Bee

Grade Bee is a mobile application for teachers to record notes and generate report cards for
students.  It is built with Flutter and Appwrite.

## Development Environment

### Quick Start
```bash
# Set up development environment
just env dev

# Pull latest configuration from Appwrite
just pull dev

# Push changes to Appwrite
just push dev
```

### Available Commands
```bash
# Show all available commands
just --list
just help

# Environment management
just env <name>        # Set environment (dev/prod/test)
just status            # Show environment status

# Appwrite operations
just push <env>        # Push to Appwrite
just pull <env>        # Pull from Appwrite
just promote           # Promote dev to prod

# Web operations
just build-web         # Build Flutter web app
just publish-web <env> # Publish web app
just deploy <env>      # Full deployment (build + publish)

# Utilities
just clean             # Clean build artifacts
```

For appwrite functions:

 - install appwrite CLI
 - run a function with `appwrite run functions`
 - copy functions/env.sample to functions/.env and edit to provide the correct
   environment variables
 - run `appwrite run functions --with-variables` to run the function locally
 - run `appwrite push functions` to deploy functions

## Data Model

- a class has a list of students, and a list of notes
- a note has a list of student notes
- a student note has a student and a text
- a student has a list of notes, and a list of generated report cards
- a report card template has a list of template sections
- a report card is built from a template.  It has a list of sections

- I can view a class with its students and notes.  I can add a note, or add a student.
- I can view a student with his notes and reports.  I can't directly add a note.

## Deployment

### Web

The web application is deployed to S3. Use the new Just commands:

```bash
# Deploy to production
just deploy prod

# Deploy to development
just deploy dev

# Or step by step
just env prod
just build-web
just publish-web prod
```

This will do 3 things:

- build the web application, using flutter
- copy the files to the S3 bucket under the `dev` or `prod` prefix
- run `aws amplify start-deployment` to create a deployment of the corresponding branch

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
