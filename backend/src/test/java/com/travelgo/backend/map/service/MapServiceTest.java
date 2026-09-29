package com.travelgo.backend.map.service;

import com.travelgo.backend.map.dto.LatLngDto;
import com.travelgo.backend.map.dto.RouteRequestDto;
import com.travelgo.backend.map.dto.RouteResultDto;
import com.travelgo.backend.map.provider.RoutingProvider;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class MapServiceTest {

    @Test
    void returnsExplicitFallbackWhenOsrmFails() {
        RoutingProvider unavailableOsrm = new RoutingProvider() {
            @Override
            public RouteResultDto calculateRoute(RouteRequestDto request) {
                throw new IllegalStateException("OSRM timeout");
            }

            @Override
            public String getProviderName() {
                return "osrm";
            }
        };
        RoutingProvider fallback = new RoutingProvider() {
            @Override
            public RouteResultDto calculateRoute(RouteRequestDto request) {
                return new RouteResultDto(
                        true,
                        new RouteResultDto.RouteMetadata("offline_fallback", true, false, "OSRM timeout"),
                        new RouteResultDto.RouteData(4.2, 15, request.getWaypoints())
                );
            }

            @Override
            public String getProviderName() {
                return "offline_fallback";
            }
        };
        MapService service = new MapService(unavailableOsrm, fallback);
        RouteRequestDto request = new RouteRequestDto();
        request.setWaypoints(List.of(new LatLngDto(10.7725, 106.6578), new LatLngDto(11.9404, 108.4583)));

        RouteResultDto result = service.getRoute(request);

        assertTrue(result.isSuccess());
        assertEquals("offline_fallback", result.getMetadata().getProvider());
        assertTrue(result.getMetadata().isFallback());
        assertEquals("OSRM timeout", result.getMetadata().getReason());
    }
}
