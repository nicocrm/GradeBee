package handler

import (
	"context"
	"fmt"
	"net/http"

	"golang.org/x/oauth2"
	"google.golang.org/api/drive/v3"
	"google.golang.org/api/option"
)

type setupResponse struct {
	FolderID  string `json:"folderId"`
	FolderURL string `json:"folderUrl"`
}

func handleSetup(w http.ResponseWriter, r *http.Request) {
	user, err := authenticateRequest(r)
	if err != nil {
		writeJSON(w, http.StatusUnauthorized, map[string]string{"error": err.Error()})
		return
	}

	accessToken, err := getGoogleOAuthToken(user.UserID)
	if err != nil {
		writeJSON(w, http.StatusBadGateway, map[string]string{"error": err.Error()})
		return
	}

	ctx := r.Context()
	rootID, err := ensureDriveFolders(ctx, accessToken)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}

	writeJSON(w, http.StatusOK, setupResponse{
		FolderID:  rootID,
		FolderURL: fmt.Sprintf("https://drive.google.com/drive/folders/%s", rootID),
	})
}


func ensureDriveFolders(ctx context.Context, accessToken string) (string, error) {
	tokenSource := oauth2.StaticTokenSource(&oauth2.Token{AccessToken: accessToken})
	srv, err := drive.NewService(ctx, option.WithTokenSource(tokenSource))
	if err != nil {
		return "", fmt.Errorf("creating drive service: %w", err)
	}

	// Find or create root GradeBee folder
	rootID, err := findOrCreateFolder(srv, "root", "GradeBee")
	if err != nil {
		return "", fmt.Errorf("creating root folder: %w", err)
	}

	// Create subfolders
	subfolders := []string{"uploads", "notes", "reports"}
	for _, name := range subfolders {
		if _, err := findOrCreateFolder(srv, rootID, name); err != nil {
			return "", fmt.Errorf("creating %s folder: %w", name, err)
		}
	}

	return rootID, nil
}

func findOrCreateFolder(srv *drive.Service, parentID, name string) (string, error) {
	// Search for existing folder
	q := fmt.Sprintf("name='%s' and '%s' in parents and mimeType='application/vnd.google-apps.folder' and trashed=false", name, parentID)
	result, err := srv.Files.List().Q(q).Fields("files(id)").Do()
	if err != nil {
		return "", err
	}
	if len(result.Files) > 0 {
		return result.Files[0].Id, nil
	}

	// Create folder
	folder := &drive.File{
		Name:     name,
		MimeType: "application/vnd.google-apps.folder",
		Parents:  []string{parentID},
	}
	created, err := srv.Files.Create(folder).Fields("id").Do()
	if err != nil {
		return "", err
	}
	return created.Id, nil
}
