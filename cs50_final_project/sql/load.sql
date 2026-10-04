PRAGMA foreign_keys = ON;
ATTACH DATABASE 'scratch.db' AS stg;

INSERT INTO drivers (abbreviation, full_name)
SELECT
    driver_code,
    MAX(full_name)
FROM stg_results
GROUP BY driver_code;

INSERT INTO teams (name)
SELECT DISTINCT team
FROM stg.stg_results
WHERE team NOT IN (SELECT name FROM teams);

INSERT INTO entries (driver_id, team_id, season, driver_number)
SELECT DISTINCT
    d.id,
    t.team_id,
    r.year,
    r.driver_number
FROM stg.stg_results r
JOIN drivers d
    ON d.abbreviation = r.driver_code
JOIN teams t
    ON t.name = r.team
WHERE NOT EXISTS (
    SELECT 1
    FROM entries e
    WHERE e.driver_id = d.id
      AND e.season = r.year
      AND e.team_id = t.team_id
);

INSERT INTO circuits (name, country)
SELECT DISTINCT circuit_name, country
FROM stg.stg_events
WHERE circuit_name NOT IN (SELECT name FROM circuits);

INSERT INTO events (circuit_id, date, season, event_name)
SELECT DISTINCT c.circuit_id, e.event_date, e.year, e.event_name
FROM stg.stg_events e
JOIN circuits c ON c.name = e.circuit_name
WHERE NOT EXISTS (
    SELECT 1 FROM events ev
    WHERE ev.event_name = e.event_name AND ev.season = e.year
);

INSERT INTO sessions (session_type, session_date, event_id)
SELECT DISTINCT r.session_type, ev.date, ev.event_id
FROM stg.stg_results r
JOIN stg.stg_events se ON se.race_id = r.race_id
JOIN events ev ON ev.event_name = se.event_name AND ev.season = se.year
WHERE NOT EXISTS (
    SELECT 1 FROM sessions s
    WHERE s.event_id = ev.event_id AND s.session_type = r.session_type
);

INSERT INTO results (entry_id, session_id, finish_position, grid_position, points, status)
SELECT
    e.entry_id,
    s.session_id,
    r.finish_position,
    r.grid_position,
    r.points,
    NULLIF(r.status, '')
FROM stg.stg_results r
JOIN drivers d ON d.abbreviation = r.driver_code
JOIN entries e
    ON e.driver_id = d.id
   AND e.season = r.year
JOIN teams t
    ON t.team_id = e.team_id
   AND t.name = r.team
JOIN (SELECT DISTINCT race_id, event_name, year FROM stg.stg_events) se ON se.race_id = r.race_id
JOIN events ev ON ev.event_name = se.event_name AND ev.season = se.year
JOIN sessions s ON s.event_id = ev.event_id AND s.session_type = r.session_type
WHERE NOT EXISTS (
    SELECT 1 FROM results res
    WHERE res.entry_id = e.entry_id AND res.session_id = s.session_id
);

INSERT INTO laps (
    session_id, entry_id, sector_time_1, sector_time_2, sector_time_3,
    lap_time, lap_number, tyre_life, compound, pit_in, pit_out,
    stint, track_status, position, deleted_lap, deleted_lap_reason, time_seconds
)
SELECT
    s.session_id,
    e.entry_id,
    l.sector_time_1,
    l.sector_time_2,
    l.sector_time_3,
    l.lap_time_seconds,
    l.lap_number,
    l.tyre_life,
    NULLIF(l.compound, 'None'),
    l.pit_in,
    l.pit_out,
    l.stint,
    l.track_status,
    l.position,
    l.deleted_lap,
    NULLIF(l.deleted_lap_reason, ''),
    l.time_seconds
FROM stg.stg_laps l
JOIN drivers d ON d.abbreviation = l.driver_code
JOIN entries e
    ON e.driver_id = d.id
   AND e.season = l.year
JOIN teams t
    ON t.team_id = e.team_id
   AND t.name = l.team
JOIN (SELECT DISTINCT race_id, event_name, year FROM stg.stg_events) se ON se.race_id = l.race_id
JOIN events ev ON ev.event_name = se.event_name AND ev.season = se.year
JOIN sessions s ON s.event_id = ev.event_id AND s.session_type = l.session_type
WHERE NOT EXISTS (
    SELECT 1 FROM laps lp
    WHERE lp.session_id = s.session_id AND lp.entry_id = e.entry_id AND lp.lap_number = l.lap_number
);

INSERT INTO weather (
    session_id, time_seconds, air_temp, wind_speed, wind_direction,
    rain, track_temp, humidity
)
SELECT
    s.session_id,
    w.time_seconds,
    w.air_temp,
    w.wind_speed,
    w.wind_direction,
    w.rainfall,
    w.track_temp,
    w.humidity
FROM stg.stg_weather w
JOIN (SELECT DISTINCT race_id, event_name, year FROM stg.stg_events) se ON se.race_id = w.race_id
JOIN events ev ON ev.event_name = se.event_name AND ev.season = se.year
JOIN sessions s ON s.event_id = ev.event_id AND s.session_type = w.session_type
WHERE NOT EXISTS (
    SELECT 1 FROM weather wx
    WHERE wx.session_id = s.session_id AND wx.time_seconds = w.time_seconds
);