import sqlite3
from pathlib import Path

import pandas as pd
import fastf1

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / "data" / "raw" / "cache"
CACHE.mkdir(parents=True, exist_ok=True)
fastf1.Cache.enable_cache(str(CACHE))

def secs(s):
    return s.dt.total_seconds()

def prep_laps(laps, race_id, session_type, year):
    return pd.DataFrame({
        "race_id": race_id,
        "session_type": session_type,
        "driver_code": laps["Driver"],
        "team": laps["Team"],
        "lap_number": laps["LapNumber"],
        "stint": laps["Stint"],
        "compound": laps["Compound"],
        "tyre_life": laps["TyreLife"],
        "lap_time_seconds": secs(laps["LapTime"]),
        "time_seconds": secs(laps["Time"]),
        "pit_in": laps["PitInTime"].notna(),
        "pit_out": laps["PitOutTime"].notna(),
        "track_status": laps["TrackStatus"],
        "position": laps["Position"],
        "deleted_lap": laps["Deleted"],
        "deleted_lap_reason": laps["DeletedReason"],
        "sector_time_1": secs(laps["Sector1Time"]),
        "sector_time_2": secs(laps["Sector2Time"]),
        "sector_time_3": secs(laps["Sector3Time"]),
        "year": year
    })

def prep_results(res, race_id, session_type, year):
    return pd.DataFrame({
        "race_id": race_id,
        "session_type": session_type,
        "driver_code": res["Abbreviation"],
        "full_name": res["FullName"],
        "driver_number": res["DriverNumber"], 
        "team": res["TeamName"],
        "grid_position": res["GridPosition"],
        "finish_position": res["Position"],
        "points": res["Points"],
        "status": res["Status"],
        "year": year
    })
    
def prep_weather(w, race_id, session_type, year):
    return pd.DataFrame({
        "race_id": race_id,
        "session_type": session_type,
        "time_seconds": secs(w["Time"]),
        "air_temp": w["AirTemp"],
        "track_temp": w["TrackTemp"],
        "humidity": w["Humidity"],
        "rainfall": w["Rainfall"],
        "wind_speed": w["WindSpeed"],
        "wind_direction": w["WindDirection"],
        "year": year

    })

def prep_event(s, race_id, event_name, year):
    ev = s.event
    return pd.DataFrame([{
        "race_id": race_id,
        "event_name": event_name,
        "circuit_name": ev["Location"],
        "country": ev["Country"],
        "event_date": str(ev["EventDate"].date()),
        "year": year,
    }])

def session_codes_for(year, event):
    sched = fastf1.get_event_schedule(year)
    row = sched[sched["EventName"] == event].iloc[0]
    if row["EventFormat"] == "conventional":
        return ["R", "Q"]
    else:
        return ["R", "Q", "S", "SQ"]

def load_session(conn, year, event, code):
    s = fastf1.get_session(year, event, code)
    s.load(telemetry=False, weather=True, messages=True)
    race_id = f"{year}_{event}"
    prep_laps(s.laps, race_id, code, year).to_sql("stg_laps", conn, if_exists="append", index=False)
    prep_results(s.results, race_id, code, year).to_sql("stg_results", conn, if_exists="append", index=False)
    prep_weather(s.weather_data, race_id, code, year).to_sql("stg_weather", conn, if_exists="append", index=False)
    prep_event(s, race_id, event, year).to_sql("stg_events", conn, if_exists="append", index=False)

def get_completed_events(year):
    schedule = fastf1.get_event_schedule(year)
    today = pd.Timestamp.today()
    is_completed = (schedule["EventDate"] <= today).values
    is_not_testing = (schedule["EventFormat"] != "testing").values
    completed = schedule[is_completed & is_not_testing]
    return completed

if __name__ == "__main__":
    DB_DIR = ROOT / "db"
    DB_DIR.mkdir(exist_ok=True)
    conn = sqlite3.connect(DB_DIR / "scratch.db")

    

    #races = [(2025, "Italian Grand Prix"), (2025, "Singapore Grand Prix"), (2025, "Belgian Grand Prix")]

   # for year, event in races:
    #    for code in session_codes_for(year, event):
     #       try:
      #          print(f"loading {year} {event} {code}...")
       #         load_session(conn, year, event, code)
        #        conn.commit()
         ##      print(f"  failed: {code} — {e}")

    years = [2025, 2026]

for year in years:

    try:
        schedule = get_completed_events(year)
    except Exception as e:
        print(f"Could not load {year} schedule: {e}")
        continue

    for _, event_row in schedule.iterrows():

        event = event_row["EventName"]
        event_format = event_row["EventFormat"]

        if event_format == "conventional":
            codes = ["R", "Q"]
        else:
            codes = ["R", "Q", "S", "SQ"]

        for code in codes:

            try:
                print(f"loading {year} {event} {code}...")

                load_session(
                    conn,
                    year,
                    event,
                    code
                )

                conn.commit()

            except Exception as e:
                print(f"  failed: {year} {event} {code} — {e}")
