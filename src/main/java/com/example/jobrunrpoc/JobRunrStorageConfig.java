package com.example.jobrunrpoc;

import javax.sql.DataSource;
import org.jobrunr.jobs.mappers.JobMapper;
import org.jobrunr.storage.StorageProvider;
import org.jobrunr.storage.sql.common.SqlStorageProviderFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class JobRunrStorageConfig {

    @Bean
    public StorageProvider storageProvider(DataSource dataSource, JobMapper jobMapper) {
        StorageProvider storageProvider = SqlStorageProviderFactory.using(dataSource);
        storageProvider.setJobMapper(jobMapper);
        return storageProvider;
    }
}
