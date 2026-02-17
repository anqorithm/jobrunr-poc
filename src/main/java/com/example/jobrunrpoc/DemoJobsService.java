package com.example.jobrunrpoc;

import java.time.Instant;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import org.jobrunr.jobs.annotations.Job;
import org.jobrunr.jobs.annotations.Recurring;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

@Service
public class DemoJobsService {

    private static final Logger log = LoggerFactory.getLogger(DemoJobsService.class);
    private final Set<String> firstAttemptKeys = ConcurrentHashMap.newKeySet();

    @Job(name = "fire-and-forget-job")
    public void fireAndForget(String source) {
        log.info("JobRunr fire-and-forget from={} at={}", source, Instant.now());
    }

    @Job(name = "delayed-job")
    public void delayed(String payload) {
        log.info("JobRunr delayed job payload={} at={}", payload, Instant.now());
    }

    @Job(name = "slow-job")
    public void slow(String payload) throws InterruptedException {
        log.info("JobRunr slow job started payload={} at={}", payload, Instant.now());
        Thread.sleep(7000);
        log.info("JobRunr slow job finished payload={} at={}", payload, Instant.now());
    }

    @Job(name = "failing-job")
    public void failing(String payload) {
        log.info("JobRunr failing job payload={} at={}", payload, Instant.now());
        throw new IllegalStateException("Intentional JobRunr failure for dashboard demo");
    }

    @Job(name = "fail-once-then-success-job")
    public void failOnceThenSucceed(String key) {
        if (firstAttemptKeys.add(key)) {
            log.info("JobRunr fail-once first attempt key={} at={}", key, Instant.now());
            throw new IllegalStateException("Intentional first failure for retry demo");
        }

        log.info("JobRunr fail-once recovered key={} at={}", key, Instant.now());
    }

    @Recurring(id = "heartbeat-recurring-job", cron = "*/1 * * * *")
    @Job(name = "heartbeat-recurring-job")
    public void recurringHeartbeat() {
        log.info("JobRunr recurring heartbeat at={}", Instant.now());
    }
}
