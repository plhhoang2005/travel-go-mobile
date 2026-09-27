package com.travelgo.backend.map.controller;

import com.travelgo.backend.map.dto.RouteRequestDto;
import com.travelgo.backend.map.dto.RouteResultDto;
import com.travelgo.backend.map.service.MapService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/maps")
public class MapController {

    private final MapService mapService;

    public MapController(MapService mapService) {
        this.mapService = mapService;
    }

    @PostMapping("/routes")
    public ResponseEntity<RouteResultDto> calculateRoute(@RequestBody RouteRequestDto request) {
        if (request == null || request.getWaypoints() == null || request.getWaypoints().size() < 2) {
            return ResponseEntity.badRequest().build();
        }
        
        RouteResultDto result = mapService.getRoute(request);
        
        if (!result.isSuccess()) {
            return ResponseEntity.status(503).body(result); // 503 Service Unavailable if all fail
        }
        
        return ResponseEntity.ok(result);
    }
}
