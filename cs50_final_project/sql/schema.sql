PRAGMA foreign_keys = ON;
CREATE TABLE "drivers" (
    "id" INTEGER PRIMARY KEY,
    "full_name" TEXT NOT NULL,
    "abbreviation" TEXT NOT NULL UNIQUE
);

CREATE TABLE "teams" (
    "team_id" INTEGER PRIMARY KEY,
    "name" TEXT NOT NULL UNIQUE
);

CREATE TABLE "entries" (
    "driver_id" INTEGER,

    "entry_id" INTEGER PRIMARY KEY,

    "team_id" INTEGER,

    "season" TEXT NOT NULL,
    "driver_number" INTEGER CHECK ("driver_number" BETWEEN 0 AND 99),
    UNIQUE ("driver_id", "team_id", "season"),
    FOREIGN KEY ("team_id") REFERENCES "teams"("team_id"),
    FOREIGN KEY ("driver_id") REFERENCES "drivers"("id")
);

CREATE TABLE "circuits" (
    "circuit_id" INTEGER PRIMARY KEY,
    "name" TEXT NOT NULL UNIQUE,
    "country" TEXT NOT NULL
);

CREATE TABLE "events" (
    "event_id" INTEGER PRIMARY KEY,

    "circuit_id" INTEGER,

    "date" TEXT NOT NULL,
    "season" TEXT NOT NULL,
    "event_name" TEXT NOT NULL,
    FOREIGN KEY ("circuit_id") REFERENCES "circuits"("circuit_id")
);

CREATE TABLE "sessions" (
    "session_type" TEXT CHECK ("session_type" IN ('S', 'SQ', 'Q', 'R')),

    "session_id" INTEGER PRIMARY KEY,

    "session_date" TEXT NOT NULL,

    "event_id" INTEGER,
    FOREIGN KEY ("event_id") REFERENCES "events"("event_id")
);

CREATE TABLE "results" (
    "result_id" INTEGER PRIMARY KEY,
    "entry_id" INTEGER,
    "session_id" INTEGER,
    "finish_position" INTEGER,
    "grid_position" INTEGER,
    "points" INTEGER,
    "status" TEXT CHECK (
        "status" IN ('Finished', 'Lapped', 'Retired', 'Did not start', 'Disqualified')
    ),
    UNIQUE ("entry_id", "session_id"),
    FOREIGN KEY ("entry_id") REFERENCES "entries"("entry_id"),
    FOREIGN KEY ("session_id") REFERENCES "sessions"("session_id")
);

CREATE TABLE "laps" (
    "lap_id" INTEGER PRIMARY KEY,

    "session_id" INTEGER,

    "entry_id" INTEGER,

    "sector_time_1" REAL,
    "sector_time_2" REAL,
    "sector_time_3" REAL,

    "lap_time" REAL,
    "lap_number" INTEGER NOT NULL,
    "tyre_life" INTEGER,

    "compound" TEXT CHECK (
        "compound" IN ('HARD', 'SOFT', 'MEDIUM', 'INTERMEDIATE', 'WET', 'nan', 'UNKNOWN')
    ),

    "pit_in" INTEGER NOT NULL,
    "pit_out" INTEGER NOT NULL,
    "stint" INTEGER,

    "track_status" TEXT NOT NULL,
    "position" INTEGER,

    "deleted_lap" INTEGER,

    "deleted_lap_reason" TEXT,

    "time_seconds" REAL NOT NULL,
    UNIQUE ("entry_id", "session_id", "lap_number"),
    FOREIGN KEY ("session_id") REFERENCES "sessions"("session_id"),
    FOREIGN KEY ("entry_id") REFERENCES "entries"("entry_id")
);

CREATE TABLE "weather" (
    "weather_id" INTEGER PRIMARY KEY,

    "session_id" INTEGER,

    "time_seconds" REAL NOT NULL,
    "air_temp" REAL NOT NULL,
    "wind_speed" REAL NOT NULL,
    "wind_direction" REAL NOT NULL,

    "rain" INTEGER,

    "track_temp" REAL NOT NULL,
    "humidity" INTEGER CHECK ("humidity" BETWEEN 0 AND 100),
    FOREIGN KEY ("session_id") REFERENCES "sessions"("session_id")
);

CREATE VIEW "stints" AS
SELECT
    session_id,
    entry_id,
    stint AS stint_number,
    compound,
    MIN(lap_number) AS start_lap,
    MAX(lap_number) AS end_lap
FROM laps
GROUP BY session_id, entry_id, stint, compound;
