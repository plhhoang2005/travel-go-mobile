package com.travelgo.backend.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.web.client.RestTemplateBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.web.client.RestTemplate;

import java.time.Duration;

@Configuration
public class RestTemplateConfig {

    @Value("${travelgo.osrm.timeout-seconds:3}")
    private int timeoutSeconds;

    @Value("${travelgo.supabase.timeout-seconds:8}")
    private int supabaseTimeoutSeconds;

    @Bean("osrmRestTemplate")
    public RestTemplate restTemplate(RestTemplateBuilder builder) {
        return builder
                .setConnectTimeout(Duration.ofSeconds(timeoutSeconds))
                .setReadTimeout(Duration.ofSeconds(timeoutSeconds))
                .build();
    }

    @Bean
    @Qualifier("supabaseRestTemplate")
    public RestTemplate supabaseRestTemplate(RestTemplateBuilder builder) {
        return builder
                .setConnectTimeout(Duration.ofSeconds(supabaseTimeoutSeconds))
                .setReadTimeout(Duration.ofSeconds(supabaseTimeoutSeconds))
                .build();
    }
}
