# ⚡ Split Notes By Student

This function is responsible for separating the teacher notes, captured after
each class, into a separate note by student.

## Trigger

In production, this is triggered by a database event (update or creation of a
note with the "text" attribute populated)

## Configuration

Environment variables (configured in Appwrite, for development configure in
.env):

- OPENAI_API_KEY

## Development

For development, run the function locally using `appwrite run functions
--with-variables` and use Postman to do a POST on localhost:3000 with a note
body.  The note should also contain the related class object, and the students
under that class - these are read directly from the body when doing the split.