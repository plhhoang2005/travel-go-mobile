package com.travelgo.backend.map.service;

import com.travelgo.backend.map.dto.RouteRequestDto;
import com.travelgo.backend.map.dto.RouteResultDto;
import com.travelgo.backend.map.provider.RoutingProvider;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.stereotype.Service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@Service
public class MapService {
    private static final Logger log = LoggerFactory.getLogger(MapService.class);

    private final RoutingProvider primaryProvider;
    private final RoutingProvider fallbackProvider;

    public MapService(
            @Qualifier("osrmRoutingProvider") RoutingProvider primaryProvider,
            @Qualifier("fallbackRoutingProvider") RoutingProvider fallbackProvider) {
        this.primaryProvider = primaryProvider;
        this.fallbackProvider = fallbackProvider;
    }

    public RouteResultDto getRoute(RouteRequestDto request) {
        try {
            log.info("Attempting to get route from primary provider: {}", primaryProvider.getProviderName());
            return primaryProvider.calculateRoute(request);
        } catch (Exception e) {
            log.warn("Primary provider [{}] failed: {}. Switching to Fallback.", primaryProvider.getProviderName(), e.getMessage());
            
            try {
                return fallbackProvider.calculateRoute(request);
            } catch (Exception fallbackEx) {
                log.error("Fallback provider also failed", fallbackEx);
                RouteResultDto.RouteMetadata metadata = new RouteResultDto.RouteMetadata("none", true, false, "All providers failed");
                return new RouteResultDto(false, metadata, null);
            }
        }
    }
}
