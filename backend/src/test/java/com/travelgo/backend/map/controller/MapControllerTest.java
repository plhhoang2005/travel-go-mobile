package com.travelgo.backend.map.controller;

import com.travelgo.backend.map.dto.LatLngDto;
import com.travelgo.backend.map.dto.RouteRequestDto;
import com.travelgo.backend.map.dto.RouteResultDto;
import com.travelgo.backend.map.service.MapService;
import org.junit.jupiter.api.Test;
import org.springframework.http.ResponseEntity;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

class MapControllerTest {

    @Test
    void rejectsRequestsWithInvalidCoordinates() {
        MapService mapService = mock(MapService.class);
        MapController controller = new MapController(mapService);
        RouteRequestDto request = requestWith(new LatLngDto(91.0, 106.6578), new LatLngDto(11.9404, 108.4583));

        ResponseEntity<RouteResultDto> response = controller.calculateRoute(request);

        assertEquals(400, response.getStatusCode().value());
        verifyNoInteractions(mapService);
    }

    @Test
    void returnsTheSuccessfulOsrmRoute() {
        MapService mapService = mock(MapService.class);
        MapController controller = new MapController(mapService);
        RouteRequestDto request = requestWith(new LatLngDto(10.7725, 106.6578), new LatLngDto(11.9404, 108.4583));
        RouteResultDto route = new RouteResultDto(
                true,
                new RouteResultDto.RouteMetadata("osrm", false, false, "Success"),
                new RouteResultDto.RouteData(290.0, 360, request.getWaypoints())
        );
        when(mapService.getRoute(request)).thenReturn(route);

        ResponseEntity<RouteResultDto> response = controller.calculateRoute(request);

        assertEquals(200, response.getStatusCode().value());
        assertNotNull(response.getBody());
        assertEquals("osrm", response.getBody().getMetadata().getProvider());
        assertEquals(false, response.getBody().getMetadata().isFallback());
    }

    private RouteRequestDto requestWith(LatLngDto... points) {
        RouteRequestDto request = new RouteRequestDto();
        request.setWaypoints(List.of(points));
        return request;
    }
}
