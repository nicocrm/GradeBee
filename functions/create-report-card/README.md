# ⚡ Create Report Card

This function is responsible for generating the report card, based on a selected template,
for one or more student under a given class.

## Trigger

In production, this is invoked from the student details screen, passing a classId, studentId,
and reportCardTemplateId.

## Configuration

Environment variables (configured in Appwrite, for development configure in
.env):

- OPENAI_API_KEY

## Development

For development, run the function locally using `appwrite run functions
--with-variables` and use Postman to do a POST on localhost:3000 with a request containing:

 - classId
 - studentId
 - reportCardTemplateId
