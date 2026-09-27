package com.travelgo.backend.map.provider;

import com.travelgo.backend.map.dto.RouteRequestDto;
import com.travelgo.backend.map.dto.RouteResultDto;

public interface RoutingProvider {
    /**
     * Calculates route based on waypoints
     * @param request The route request containing waypoints
     * @return Normalized RouteResultDto
     * @throws Exception If provider fails (timeout, rate limit, etc.)
     */
    RouteResultDto calculateRoute(RouteRequestDto request) throws Exception;
    
    /**
     * Provider identifier (e.g. "osrm", "mapbox")
     */
    String getProviderName();
}
