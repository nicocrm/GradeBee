package handler

import (
	"errors"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestClassRepo_CreateWithLevelAndTimeSlot(t *testing.T) {
	db := setupTestDB(t)
	repo := &ClassRepo{db: db}
	level := newTestLevel(t, db, "org1", "Mousy")

	c, err := repo.Create(t.Context(), "org1", "user1", level.ID, "Thursday")
	require.NoError(t, err)
	assert.Equal(t, "Mousy", c.LevelName)
	assert.Equal(t, "Thursday", c.TimeSlot)
	assert.Equal(t, "Mousy · Thursday", c.Name)
}

func TestClassRepo_CreateNoTimeSlot(t *testing.T) {
	db := setupTestDB(t)
	repo := &ClassRepo{db: db}
	level := newTestLevel(t, db, "org1", "Lions")

	c, err := repo.Create(t.Context(), "org1", "user1", level.ID, "")
	require.NoError(t, err)
	assert.Equal(t, "Lions", c.Name)
	assert.Empty(t, c.TimeSlot)
}

func TestClassRepo_CreateCrossGroupLevelRejected(t *testing.T) {
	db := setupTestDB(t)
	repo := &ClassRepo{db: db}
	level := newTestLevel(t, db, "org1", "Marcia")

	_, err := repo.Create(t.Context(), "org2", "user1", level.ID, "")
	assert.True(t, errors.Is(err, ErrNotFound), "expected ErrNotFound for cross-group level, got %v", err)
}

func TestClassRepo_UpdateCrossGroupLevelRejected(t *testing.T) {
	db := setupTestDB(t)
	repo := &ClassRepo{db: db}
	levelA := newTestLevel(t, db, "org1", "Marcia")
	levelB := newTestLevel(t, db, "org2", "Oliver")

	c, err := repo.Create(t.Context(), "org1", "user1", levelA.ID, "")
	require.NoError(t, err)

	err = repo.Update(t.Context(), "org1", "user1", c.ID, levelB.ID, "")
	assert.True(t, errors.Is(err, ErrNotFound), "expected ErrNotFound for cross-group level, got %v", err)
}

func TestClassRepo_DuplicateLevelTimeSlot(t *testing.T) {
	db := setupTestDB(t)
	repo := &ClassRepo{db: db}
	level := newTestLevel(t, db, "org1", "Mousy")

	_, err := repo.Create(t.Context(), "org1", "user1", level.ID, "Thursday")
	require.NoError(t, err)
	_, err = repo.Create(t.Context(), "org1", "user1", level.ID, "Thursday")
	assert.True(t, errors.Is(err, ErrDuplicate), "expected ErrDuplicate, got %v", err)
}

func TestClassRepo_CreateNameMatchesReadName(t *testing.T) {
	db := setupTestDB(t)
	repo := &ClassRepo{db: db}
	level := newTestLevel(t, db, "org1", "Mousy")

	created, err := repo.Create(t.Context(), "org1", "user1", level.ID, "Thursday")
	require.NoError(t, err)

	read, err := repo.GetByID(t.Context(), created.ID)
	require.NoError(t, err)
	assert.Equal(t, read.Name, created.Name, "create-path name must match the read-path derived name")
}
