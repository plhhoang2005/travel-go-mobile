package com.travelgo.backend.config;

import com.github.benmanes.caffeine.cache.Caffeine;
import com.travelgo.backend.map.dto.RouteRequestDto;
import org.springframework.cache.CacheManager;
import org.springframework.cache.caffeine.CaffeineCacheManager;
import org.springframework.cache.interceptor.KeyGenerator;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.Locale;
import java.util.concurrent.TimeUnit;
import java.util.stream.Collectors;

@Configuration
public class CacheConfig {

    @Bean
    public Caffeine<Object, Object> caffeineConfig() {
        return Caffeine.newBuilder()
                .expireAfterWrite(2, TimeUnit.HOURS)
                .maximumSize(1000)
                .recordStats();
    }

    @Bean
    public CacheManager cacheManager(Caffeine<Object, Object> caffeine) {
        CaffeineCacheManager caffeineCacheManager = new CaffeineCacheManager("osrm-routes");
        caffeineCacheManager.setCaffeine(caffeine);
        return caffeineCacheManager;
    }

    @Bean("routeCacheKeyGenerator")
    public KeyGenerator keyGenerator() {
        return (target, method, params) -> {
            if (params.length > 0 && params[0] instanceof RouteRequestDto) {
                RouteRequestDto request = (RouteRequestDto) params[0];
                if (request.getWaypoints() != null) {
                    return request.getWaypoints().stream()
                            .map(wp -> String.format(Locale.US, "%.6f,%.6f", wp.getLat(), wp.getLng()))
                            .collect(Collectors.joining(";"));
                }
            }
            return "default_key";
        };
    }
}
