package com.example.jobrunrpoc;

import java.time.Instant;
import java.util.Map;
import java.util.UUID;
import org.jobrunr.jobs.JobId;
import org.jobrunr.scheduling.JobScheduler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
class DemoController {

    private final JobScheduler jobScheduler;
    private final DemoJobsService demoJobsService;

    DemoController(JobScheduler jobScheduler, DemoJobsService demoJobsService) {
        this.jobScheduler = jobScheduler;
        this.demoJobsService = demoJobsService;
    }

    @GetMapping("/")
    Map<String, String> home() {
        return Map.of(
            "service", "jobrunr-poc",
            "status", "running",
            "timestamp", Instant.now().toString(),
            "dashboard", "http://localhost:8000/dashboard",
            "cases", "GET /jobs/cases"
        );
    }

    @GetMapping("/jobs/cases")
    Map<String, String> cases() {
        return Map.of(
            "enqueue", "POST /jobs/enqueue",
            "delayed", "POST /jobs/delayed?delaySeconds=15",
            "slow", "POST /jobs/slow",
            "alwaysFail", "POST /jobs/fail",
            "failOnceThenSucceed", "POST /jobs/fail-once"
        );
    }

    @PostMapping("/jobs/enqueue")
    Map<String, String> enqueue(@RequestParam(name = "source", defaultValue = "api") String source) {
        JobId jobId = jobScheduler.enqueue(() -> demoJobsService.fireAndForget(source));
        return Map.of("jobId", jobId.asUUID().toString(), "type", "fire-and-forget");
    }

    @PostMapping("/jobs/delayed")
    Map<String, String> delayed(@RequestParam(name = "delaySeconds", defaultValue = "10") long delaySeconds) {
        Instant scheduledAt = Instant.now().plusSeconds(delaySeconds);
        JobId jobId = jobScheduler.schedule(scheduledAt, () -> demoJobsService.delayed("delaySeconds=" + delaySeconds));
        return Map.of(
            "jobId", jobId.asUUID().toString(),
            "type", "delayed",
            "scheduledAt", scheduledAt.toString()
        );
    }

    @PostMapping("/jobs/slow")
    Map<String, String> slow() {
        JobId jobId = jobScheduler.enqueue(() -> demoJobsService.slow("slow-from-api"));
        return Map.of("jobId", jobId.asUUID().toString(), "type", "slow");
    }

    @PostMapping("/jobs/fail")
    Map<String, String> fail() {
        JobId jobId = jobScheduler.enqueue(() -> demoJobsService.failing("fail-from-api"));
        return Map.of("jobId", jobId.asUUID().toString(), "type", "failing");
    }

    @PostMapping("/jobs/fail-once")
    Map<String, String> failOnceThenSucceed() {
        String key = UUID.randomUUID().toString();
        JobId jobId = jobScheduler.enqueue(() -> demoJobsService.failOnceThenSucceed(key));
        return Map.of(
            "jobId", jobId.asUUID().toString(),
            "type", "fail-once-then-success",
            "correlationKey", key
        );
    }
}
