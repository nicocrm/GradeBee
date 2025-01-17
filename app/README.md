# GradeBee Mobile App

## Development Environment Setup

## Configuration

## Component Layout

### /features

All feature-specific code should go here.
This includes the models, even though it might duplicate some of the code that is shared with the functions, because
we typically need different properties in the models for the different features.

 - auth: login screen, signup screen, forgot password screen, etc.
 - class_list: management of classes

### /shared

All code that is used by multiple features should go here.

 - ui: shared UI components and settings
 - data: shared data services, including database, authentication, and storage
 - routes: navigation logic