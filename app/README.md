# GradeBee Mobile App

## Development Environment Setup

## Configuration

## Component Layout

### /features

All feature-specific code should go here.
This includes the models, even though it might duplicate some of the code that is shared with the functions, because
we typically need different properties in the models for the different features.

 - auth: login screen, signup screen, forgot password screen, etc.
 - class_list: view list of classes, add a class, record a note under a class
 - student_details: view details of a student, view report cards for a student, generate report cards for a specific student

### /shared

All code that is used by multiple features should go here.

 - ui: shared UI components and settings
 - data: shared data services, including database, authentication, and storage
 - routes: navigation logic

