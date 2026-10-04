-- QUERY 1

SELECT AVG(lap_time), tyre_life, compound, COUNT(*) FROM laps
WHERE deleted_lap = 0 AND pit_in = 0 AND pit_out = 0 AND track_status = 1 AND compound IS NOT NULL AND compound != 'UNKNOWN'
GROUP BY compound, tyre_life
;

-- QUERY 2

SELECT
    weather_summary.rain,
    c.name,
    l.compound,
    AVG(l.lap_time),
    COUNT(lap_number),
    AVG(weather_summary.avg_track_temp)
FROM laps l 
JOIN (SELECT session_id, AVG(track_temp) AS avg_track_temp, MAX(rain) AS rain
FROM weather
GROUP BY session_id) AS weather_summary ON weather_summary.session_id = l.session_id
JOIN sessions s ON l.session_id = s.session_id
JOIN events e ON e.event_id = s.event_id
JOIN circuits c ON c.circuit_id = e.circuit_id
WHERE deleted_lap = 0 AND pit_in = 0 AND pit_out = 0 AND track_status = 1 AND compound IS NOT NULL AND compound != 'UNKNOWN' AND session_type = 'R'
GROUP BY c.name, l.compound, weather_summary.rain
;

--QUERY 3

SELECT ordered.session_id, ordered.entry_id, GROUP_CONCAT(compound , '->'), finish_position FROM (
    SELECT stints.session_id, entry_id, stint_number, compound FROM sessions
    JOIN stints ON sessions.session_id = stints.session_id 
    WHERE session_type = 'R'
    ORDER BY stints.session_id, stints.entry_id, stint_number
) AS ordered
JOIN results ON ordered.session_id = results.session_id AND ordered.entry_id = results.entry_id
GROUP BY ordered.session_id, ordered.entry_id
;

--QUERY 4

SELECT grid_position - finish_position AS positions_gained, abbreviation
FROM results
JOIN entries ON results.entry_id = entries.entry_id
JOIN drivers ON entries.driver_id = drivers.id
JOIN sessions ON results.session_id = sessions.session_id
WHERE session_type IN ('R', 'S');

--QUERY 7

SELECT AVG(sector_time_1),AVG(sector_time_2), AVG(sector_time_3), tyre_life, compound, COUNT(*) FROM laps
WHERE deleted_lap = 0 AND pit_in = 0 AND pit_out = 0 AND track_status = 1 AND compound IS NOT NULL AND compound != 'UNKNOWN' AND tyre_life > 1
GROUP BY compound, tyre_life
;

-- QUERY 5

SELECT
    d1.full_name AS driver1,
    d2.full_name AS driver2,
    ev.season,
ev.event_name,
    a1.compound,
    ROUND(a1.avg_lap_time, 3) AS driver1_avg,
    ROUND(a2.avg_lap_time, 3) AS driver2_avg,
    a1.lap_count AS driver1_laps,
    a2.lap_count AS driver2_laps,
    ROUND(a1.avg_lap_time - a2.avg_lap_time, 3) AS difference
FROM entries e1
JOIN drivers d1
    ON d1.id = e1.driver_id
JOIN entries e2
    ON e1.team_id = e2.team_id
   AND e1.season = e2.season
   AND e1.driver_id < e2.driver_id
JOIN drivers d2
    ON d2.id = e2.driver_id
JOIN (
    SELECT
        entry_id,
        l.session_id,
        compound,
        AVG(lap_time) AS avg_lap_time,
        COUNT(lap_time) AS lap_count
    FROM laps l
    JOIN sessions s
        ON s.session_id = l.session_id
    WHERE compound IS NOT NULL
      AND compound NOT IN ('nan', 'UNKNOWN')
      AND lap_time IS NOT NULL
      AND deleted_lap = 0
      AND pit_in = 0
      AND pit_out = 0
      AND s.session_type = 'R'
    GROUP BY
        entry_id,
        l.session_id,
        compound
) AS a1
ON a1.entry_id = e1.entry_id
JOIN sessions s
    ON s.session_id = a1.session_id
JOIN events ev
    ON ev.event_id = s.event_id
JOIN (
    SELECT
        entry_id,
        l.session_id,
        compound,
        AVG(lap_time) AS avg_lap_time,
        COUNT(lap_time) AS lap_count
    FROM laps l
    JOIN sessions s
        ON s.session_id = l.session_id
    WHERE compound IS NOT NULL
      AND compound NOT IN ('nan', 'UNKNOWN')
      AND lap_time IS NOT NULL
      AND deleted_lap = 0
      AND pit_in = 0
      AND pit_out = 0
      AND s.session_type = 'R'
    GROUP BY
        entry_id,
        l.session_id,
        compound
) AS a2
ON a2.entry_id = e2.entry_id
AND a2.session_id = a1.session_id
AND a2.compound = a1.compound
WHERE a1.lap_count >= 10
  AND a2.lap_count >= 10;


--QUERY 6
SELECT
    weather_summary.rain,
    c.name,
    d.abbreviation,
    GROUP_CONCAT(stints.compound, '->'),
    ROUND(weather_summary.avg_wind, 3),
    r.finish_position
FROM (
    SELECT session_id, entry_id, stint_number, compound
    FROM stints
    WHERE compound IS NOT NULL
      AND compound NOT IN ('UNKNOWN', 'nan')
    ORDER BY session_id, entry_id, stint_number
) AS stints
JOIN (SELECT session_id, AVG(wind_speed) AS avg_wind, MAX(rain) AS rain
FROM weather
GROUP BY session_id) AS weather_summary ON weather_summary.session_id = stints.session_id
JOIN sessions s ON stints.session_id = s.session_id
JOIN events e ON e.event_id = s.event_id
JOIN circuits c ON c.circuit_id = e.circuit_id
JOIN results r
    ON stints.session_id = r.session_id
   AND stints.entry_id = r.entry_id
JOIN entries en ON en.entry_id = stints.entry_id
JOIN drivers d ON d.id = en.driver_id
WHERE s.session_type = 'R'
  AND stints.compound IS NOT NULL
  AND stints.compound NOT IN ('UNKNOWN', 'nan')
GROUP BY
    stints.session_id,
    stints.entry_id,
    c.name,
    weather_summary.rain,
    weather_summary.avg_wind,
    r.finish_position
;

--QUERY 8

INSERT INTO circuits (name, country)
VALUES ('Example Circuit', 'Armenia');
INSERT INTO events (circuit_id, date, season, event_name)
SELECT circuit_id, '2026-10-25', '2026', 'Armenian Grand Prix'
FROM circuits WHERE name = 'Example Circuit';
INSERT INTO sessions (event_id, session_date, session_type)
SELECT event_id, '2026-10-25', 'R'
FROM events WHERE event_name = 'Armenian Grand Prix';
INSERT INTO weather (session_id, time_seconds, air_temp, wind_speed, wind_direction, rain, track_temp, humidity)
VALUES (last_insert_rowid(), 0, 22.0, 2.5, 180, 0, 31.0, 55);
INSERT INTO results (entry_id, session_id, finish_position, grid_position, points, status)
SELECT
    e.entry_id,
    s.session_id,
    1,
    1,
    25, 
    'Finished'
FROM sessions s
JOIN events ev ON ev.event_id = s.event_id
JOIN drivers d ON d.abbreviation = 'VER'
JOIN entries e ON e.driver_id = d.id AND e.season = '2026'
WHERE ev.event_name = 'Armenian Grand Prix';

--QUERY 9

UPDATE results
SET
    finish_position = 5,
    points = 10
WHERE result_id = 99902;

--QUERY 10
DELETE FROM laps
WHERE lap_id NOT IN (
    SELECT MIN(lap_id) FROM laps GROUP BY entry_id, session_id, lap_number
);
