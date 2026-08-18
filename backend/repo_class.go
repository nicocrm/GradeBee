package handler

import (
	"context"
	"database/sql"
	"fmt"
)

// ClassRepo provides CRUD operations for the classes table.
type ClassRepo struct{ db *sql.DB }

// Class represents a row in the classes table. Name and LevelName are not
// stored — both are derived from the referenced Level's name, so renaming a
// Level immediately changes every Class's display name.
type Class struct {
	ID        int64  `json:"id"`
	UserID    string `json:"userId"`
	Name      string `json:"name"`
	LevelID   int64  `json:"levelId"`
	LevelName string `json:"levelName"`
	TimeSlot  string `json:"timeSlot"`
	Position  int    `json:"position"`
	CreatedAt string `json:"createdAt"`
}

// ClassWithCount is a Class with its student count.
type ClassWithCount struct {
	Class        `tstype:",extends"`
	StudentCount int `json:"studentCount"`
}

// classDisplayNameSQL is the shared SQL expression for a Class's display
// name: the Level's name, plus " · time slot" when a time slot is set. Every
// query that needs the display name — read or lookup — must use this
// expression rather than reimplementing it, so it can never drift from
// deriveClassDisplayName, its Go equivalent used by the create path.
const classDisplayNameSQL = `l.name || CASE WHEN c.time_slot <> '' THEN ' · ' || c.time_slot ELSE '' END`

// classSelectColumns is the shared SELECT list used by every read query: the
// stored columns, the Level's bare name, and the derived display name
// (Level's name, plus " · time slot" when a time slot is set).
const classSelectColumns = `
	c.id, c.user_id,
	` + classDisplayNameSQL + `,
	c.level_id, l.name, c.time_slot, c.position, c.created_at`

// deriveClassDisplayName composes a Class's display name from its Level's
// name and time slot. This is the Go equivalent of classDisplayNameSQL —
// used by the create path, which builds the name in Go before there is a
// row to re-select — and both must always agree.
func deriveClassDisplayName(levelName, timeSlot string) string {
	if timeSlot == "" {
		return levelName
	}
	return levelName + " · " + timeSlot
}

// List returns all classes for a user, ordered by position then the derived
// name, including the count of students in each class.
func (r *ClassRepo) List(ctx context.Context, userID string) ([]ClassWithCount, error) {
	rows, err := r.db.QueryContext(ctx, `
		SELECT `+classSelectColumns+`, COUNT(s.id)
		FROM classes c
		JOIN levels l ON l.id = c.level_id
		LEFT JOIN students s ON s.class_id = c.id
		WHERE c.user_id = ?
		GROUP BY c.id
		ORDER BY c.position, 3`, userID)
	if err != nil {
		return nil, fmt.Errorf("list classes: %w", err)
	}
	defer rows.Close()

	var result []ClassWithCount
	for rows.Next() {
		var c ClassWithCount
		if err := rows.Scan(&c.ID, &c.UserID, &c.Name, &c.LevelID, &c.LevelName, &c.TimeSlot, &c.Position, &c.CreatedAt, &c.StudentCount); err != nil {
			return nil, fmt.Errorf("scan class: %w", err)
		}
		result = append(result, c)
	}
	return result, rows.Err()
}

// Create inserts a new class for the user, referencing a Level owned by
// groupID. Position is set to max+1. Returns ErrNotFound if levelID does not
// belong to groupID — the only place a cross-Group Level reference can be
// forged, so the check belongs here rather than in a caller that might forget.
func (r *ClassRepo) Create(ctx context.Context, groupID, userID string, levelID int64, timeSlot string) (Class, error) {
	var levelName string
	err := r.db.QueryRowContext(ctx,
		"SELECT name FROM levels WHERE id = ? AND group_id = ?", levelID, groupID,
	).Scan(&levelName)
	if err == sql.ErrNoRows {
		return Class{}, fmt.Errorf("create class: level %d not in group: %w", levelID, ErrNotFound)
	}
	if err != nil {
		return Class{}, fmt.Errorf("create class: look up level: %w", err)
	}

	var c Class
	err = r.db.QueryRowContext(ctx, `
		INSERT INTO classes (user_id, level_id, time_slot, position)
		VALUES (?, ?, ?, COALESCE((SELECT MAX(position) FROM classes WHERE user_id = ?), 0) + 1)
		RETURNING id, user_id, level_id, time_slot, position, created_at`,
		userID, levelID, timeSlot, userID,
	).Scan(&c.ID, &c.UserID, &c.LevelID, &c.TimeSlot, &c.Position, &c.CreatedAt)
	if err != nil {
		if isDuplicateErr(err) {
			return Class{}, fmt.Errorf("create class: %w", ErrDuplicate)
		}
		return Class{}, fmt.Errorf("create class: %w", err)
	}
	c.LevelName = levelName
	c.Name = deriveClassDisplayName(levelName, timeSlot)
	return c, nil
}

// Update changes the Level and/or Time slot of a class owned by the user.
// Returns ErrNotFound if levelID does not belong to groupID.
func (r *ClassRepo) Update(ctx context.Context, groupID, userID string, id, levelID int64, timeSlot string) error {
	res, err := r.db.ExecContext(ctx, `
		UPDATE classes SET level_id = ?, time_slot = ?
		WHERE id = ? AND user_id = ?
		  AND EXISTS (SELECT 1 FROM levels WHERE id = ? AND group_id = ?)`,
		levelID, timeSlot, id, userID, levelID, groupID)
	if err != nil {
		if isDuplicateErr(err) {
			return fmt.Errorf("update class: %w", ErrDuplicate)
		}
		return fmt.Errorf("update class: %w", err)
	}
	return rowsAffectedOrNotFound(res)
}

// GetByID returns a single class by ID.
func (r *ClassRepo) GetByID(ctx context.Context, id int64) (Class, error) {
	var c Class
	err := r.db.QueryRowContext(ctx,
		"SELECT "+classSelectColumns+" FROM classes c JOIN levels l ON l.id = c.level_id WHERE c.id = ?", id,
	).Scan(&c.ID, &c.UserID, &c.Name, &c.LevelID, &c.LevelName, &c.TimeSlot, &c.Position, &c.CreatedAt)
	if err == sql.ErrNoRows {
		return Class{}, ErrNotFound
	}
	if err != nil {
		return Class{}, fmt.Errorf("get class: %w", err)
	}
	return c, nil
}

// Delete removes a class owned by the user. Students and notes cascade.
func (r *ClassRepo) Delete(ctx context.Context, userID string, id int64) error {
	res, err := r.db.ExecContext(ctx,
		"DELETE FROM classes WHERE id = ? AND user_id = ?", id, userID)
	if err != nil {
		return fmt.Errorf("delete class: %w", err)
	}
	return rowsAffectedOrNotFound(res)
}
