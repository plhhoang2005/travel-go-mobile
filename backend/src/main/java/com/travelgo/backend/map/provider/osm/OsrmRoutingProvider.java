package com.travelgo.backend.map.provider.osm;

import com.fasterxml.jackson.databind.JsonNode;
import com.travelgo.backend.map.dto.LatLngDto;
import com.travelgo.backend.map.dto.RouteRequestDto;
import com.travelgo.backend.map.dto.RouteResultDto;
import com.travelgo.backend.map.provider.RoutingProvider;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;

@Service("osrmRoutingProvider")
public class OsrmRoutingProvider implements RoutingProvider {

    private final RestTemplate restTemplate;

    @Value("${travelgo.osrm.base-url}")
    private String baseUrl;

    public OsrmRoutingProvider(RestTemplate restTemplate) {
        this.restTemplate = restTemplate;
    }

    @Override
    @Cacheable(cacheNames = "osrm-routes", keyGenerator = "routeCacheKeyGenerator")
    public RouteResultDto calculateRoute(RouteRequestDto request) throws Exception {
        if (request.getWaypoints() == null || request.getWaypoints().size() < 2) {
            throw new IllegalArgumentException("Need at least 2 waypoints");
        }

        String coordsString = request.getWaypoints().stream()
                .map(wp -> wp.getLng() + "," + wp.getLat())
                .collect(Collectors.joining(";"));

        String url = baseUrl + "/route/v1/driving/" + coordsString + "?overview=full&geometries=geojson";

        // Spring will automatically throw ResourceAccessException on timeout, HttpClientErrorException on 4xx
        JsonNode response = restTemplate.getForObject(url, JsonNode.class);

        if (response != null && response.has("routes") && response.get("routes").isArray() && response.get("routes").size() > 0) {
            JsonNode routeNode = response.get("routes").get(0);
            
            double distanceMeters = routeNode.has("distance") ? routeNode.get("distance").asDouble() : 0.0;
            double durationSeconds = routeNode.has("duration") ? routeNode.get("duration").asDouble() : 0.0;
            
            List<LatLngDto> points = new ArrayList<>();
            if (routeNode.has("geometry") && routeNode.get("geometry").has("coordinates")) {
                JsonNode coordsNode = routeNode.get("geometry").get("coordinates");
                for (JsonNode coord : coordsNode) {
                    double lon = coord.get(0).asDouble();
                    double lat = coord.get(1).asDouble();
                    points.add(new LatLngDto(lat, lon)); // Swap back to LatLng
                }
            }
            
            RouteResultDto.RouteMetadata metadata = new RouteResultDto.RouteMetadata(getProviderName(), false, false, "Success");
            RouteResultDto.RouteData data = new RouteResultDto.RouteData(distanceMeters / 1000.0, (int) Math.round(durationSeconds / 60.0), points);
            
            return new RouteResultDto(true, metadata, data);
        }
        
        throw new RuntimeException("Empty response from OSRM");
    }

    @Override
    public String getProviderName() {
        return "osrm";
    }
}
