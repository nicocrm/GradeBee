"""
One-time script to update permissions on notes and student notes that were mistakenly given no permissions
during the import process. This script will only update documents that have no permissions or only have
user:None permissions, leaving any documents with other permissions unchanged.
"""

from config import databases, database_id, default_user_id
from appwrite.query import Query
from appwrite.services.databases import Databases
from typing import List, cast, Dict, Any
import traceback

def has_non_none_permissions(permissions: List[str]) -> bool:
    """Check if the permissions list has any permissions other than user:None."""
    if not permissions:
        return False
        
    for permission in permissions:
        if "user:None" not in permission:
            return True
    return False

def update_document_permissions(databases: Databases, collection_id: str, document: Dict[str, Any]):
    """Update read and write permissions for a document to allow access by the default user."""
    try:
        document_id = document.get("$id")
        if not document_id:
            print("Document has no ID")
            return
            
        # Check if permissions already exist
        current_permissions = document.get('$permissions', [])
        if has_non_none_permissions(current_permissions):
            print(f"Document {document_id} in collection {collection_id} already has non-None permissions")
            return
            
        # Update permissions if needed
        databases.update_document(
            database_id=database_id,
            collection_id=collection_id,
            document_id=document_id,
            permissions=[
                f"read(\"user:{default_user_id}\")",
                f"update(\"user:{default_user_id}\")",
                f"delete(\"user:{default_user_id}\")",
            ]
        )
        print(f"Updated permissions for document {document_id} in collection {collection_id}")
    except Exception as e:
        print(f"Error updating permissions for document {document_id}: {str(e)}")
        print("Stack trace:")
        traceback.print_exc()

def update_all_notes():
    """Update permissions for all notes and related student notes."""
    # Update permissions for notes collection
    try:
        response = cast(
            dict,
            databases.list_documents(
                database_id=database_id,
                collection_id="notes",
                queries=[
                    Query.limit(1000)
                ]
            )
        )
        
        if not response:
            print("No notes found")
            return
        
        documents = response["documents"]
        if not documents:
            print("No documents found in response")
            return
            
        for note in documents:
            if not isinstance(note, dict):
                continue
                
            update_document_permissions(databases, "notes", note)
            
            # If the note has related student notes, update those as well
            if "student_notes" in note:
                student_notes = note["student_notes"]
                if isinstance(student_notes, list):
                    for student_note in student_notes:
                        if isinstance(student_note, dict):
                            update_document_permissions(databases, "student_notes", student_note)
    
    except Exception as e:
        print(f"Error processing notes: {str(e)}")
        print("Stack trace:")
        traceback.print_exc()

if __name__ == "__main__":
    update_all_notes() 