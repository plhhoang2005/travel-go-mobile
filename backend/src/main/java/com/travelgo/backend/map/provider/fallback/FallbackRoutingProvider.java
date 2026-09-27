package com.travelgo.backend.map.provider.fallback;

import com.travelgo.backend.map.dto.LatLngDto;
import com.travelgo.backend.map.dto.RouteRequestDto;
import com.travelgo.backend.map.dto.RouteResultDto;
import com.travelgo.backend.map.provider.RoutingProvider;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;

@Service("fallbackRoutingProvider")
public class FallbackRoutingProvider implements RoutingProvider {

    @Override
    public RouteResultDto calculateRoute(RouteRequestDto request) {
        double totalDistanceKm = 0;
        List<LatLngDto> points = new ArrayList<>();
        
        if (request.getWaypoints() != null && !request.getWaypoints().isEmpty()) {
            points.add(request.getWaypoints().get(0));
            for (int i = 0; i < request.getWaypoints().size() - 1; i++) {
                LatLngDto p1 = request.getWaypoints().get(i);
                LatLngDto p2 = request.getWaypoints().get(i+1);
                totalDistanceKm += calculateHaversineDistance(p1.getLat(), p1.getLng(), p2.getLat(), p2.getLng());
                points.add(p2);
            }
        }
        
        int durationMinutes = (int) Math.round((totalDistanceKm / 40.0) * 60); // Assume 40km/h avg speed
        
        RouteResultDto.RouteMetadata metadata = new RouteResultDto.RouteMetadata(
            getProviderName(), true, false, "Primary provider failed. Using Haversine fallback."
        );
        RouteResultDto.RouteData data = new RouteResultDto.RouteData(totalDistanceKm, Math.max(15, durationMinutes), points);
        
        return new RouteResultDto(true, metadata, data);
    }

    @Override
    public String getProviderName() {
        return "offline_fallback";
    }

    private double calculateHaversineDistance(double lat1, double lon1, double lat2, double lon2) {
        final int R = 6371; // Radius of the earth in km
        double latDistance = Math.toRadians(lat2 - lat1);
        double lonDistance = Math.toRadians(lon2 - lon1);
        double a = Math.sin(latDistance / 2) * Math.sin(latDistance / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                * Math.sin(lonDistance / 2) * Math.sin(lonDistance / 2);
        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return R * c;
    }
}
