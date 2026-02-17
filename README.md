# JobRunr Spring Boot 4 POC

Simple POC for JobRunr with Spring Boot 4 and H2.

## Stack

- Java 21
- Spring Boot 4.0.2
- JobRunr Spring Boot 4 starter 8.3.0
- H2 file database

## What this POC shows (all cases)

- Fire-and-forget (`Enqueued -> Succeeded`)
- Delayed (`Scheduled -> Processing -> Succeeded`)
- Slow (`Processing` visible for several seconds)
- Always fail (`Failed` with retries)
- Fail once then succeed (`Failed -> Retry -> Succeeded`)
- Recurring cron job every minute (`heartbeat-recurring-job`)

## Flow summary

- `POST /jobs/enqueue`: `Enqueued -> Processing -> Succeeded`
- `POST /jobs/delayed`: `Scheduled -> Processing -> Succeeded`
- `POST /jobs/slow`: `Processing (long-running) -> Succeeded`
- `POST /jobs/fail`: `Failed` (retries until exhausted)
- `POST /jobs/fail-once`: `Failed -> Retry -> Succeeded`
- Recurring `heartbeat-recurring-job`: runs every minute

## Run

```bash
cd /home/abdullah/Desktop/jobrunr-poc
mvn clean spring-boot:run
```

Open:

- App: `http://localhost:8081/`
- JobRunr Dashboard: `http://localhost:8000/dashboard`
- H2 Console: `http://localhost:8081/h2-console`

## API - all cases

```bash
curl -X GET  "http://localhost:8081/jobs/cases"
curl -X POST "http://localhost:8081/jobs/enqueue"
curl -X POST "http://localhost:8081/jobs/delayed?delaySeconds=15"
curl -X POST "http://localhost:8081/jobs/slow"
curl -X POST "http://localhost:8081/jobs/fail"
curl -X POST "http://localhost:8081/jobs/fail-once"
```

## Where to verify in dashboard

- `Enqueued`: job accepted and waiting worker.
- `Scheduled`: delayed job waiting for time.
- `Processing`: running now (easy to see with `slow`).
- `Succeeded`: finished successfully.
- `Failed`: failed after retries (`/jobs/fail`).
- Retry recovery example: use `/jobs/fail-once`, then inspect transitions to success.
- Recurring jobs tab: check `heartbeat-recurring-job`.

## Notes

- Recurring job id is fixed by annotation id: `heartbeat-recurring-job`.
- One-off job IDs are generated UUIDs by JobRunr and returned by API.

## Generate lots of jobs (load script)

Use the built-in load generator:

```bash
cd /home/abdullah/Desktop/jobrunr-poc
./scripts/generate-job-load.sh --total 2000 --concurrency 50
```

Custom target and delayed timing:

```bash
./scripts/generate-job-load.sh \
  --base-url http://localhost:8081 \
  --total 10000 \
  --concurrency 100 \
  --delay-seconds 30
```

It triggers all demo cases with weighted random distribution and prints a summary.
