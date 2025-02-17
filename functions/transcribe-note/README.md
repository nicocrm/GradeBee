# ⚡ Transcribe Note

This function is responsible for turning the teacher's recorded note into text.
The student names are taken into account to disambiguate pronunciation.

## Trigger

In production, this is triggered by a database event (creation of a note with
the "voice" attribute populated)

## Configuration

Environment variables (configured in Appwrite, for development configure in
.env):

- OPENAI_API_KEY

## Development

For development, run the function locally using `appwrite run functions
--with-variables` and use Postman to do a POST on localhost:3000 with a note
body.  The note should also contain the related class object, and the students
under that class - these are read directly from the body when doing the
transcript.