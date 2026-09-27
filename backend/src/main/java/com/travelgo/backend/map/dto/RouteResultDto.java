package com.travelgo.backend.map.dto;

import java.util.List;

public class RouteResultDto {
    private boolean success;
    private RouteMetadata metadata;
    private RouteData data;

    public RouteResultDto() {}

    public RouteResultDto(boolean success, RouteMetadata metadata, RouteData data) {
        this.success = success;
        this.metadata = metadata;
        this.data = data;
    }

    public boolean isSuccess() { return success; }
    public void setSuccess(boolean success) { this.success = success; }
    public RouteMetadata getMetadata() { return metadata; }
    public void setMetadata(RouteMetadata metadata) { this.metadata = metadata; }
    public RouteData getData() { return data; }
    public void setData(RouteData data) { this.data = data; }

    public static class RouteMetadata {
        private String provider;
        private boolean isFallback;
        private boolean cached;
        private String reason;

        public RouteMetadata() {}
        public RouteMetadata(String provider, boolean isFallback, boolean cached, String reason) {
            this.provider = provider;
            this.isFallback = isFallback;
            this.cached = cached;
            this.reason = reason;
        }

        public String getProvider() { return provider; }
        public void setProvider(String provider) { this.provider = provider; }
        public boolean isFallback() { return isFallback; }
        public void setFallback(boolean fallback) { this.isFallback = fallback; }
        public boolean isCached() { return cached; }
        public void setCached(boolean cached) { this.cached = cached; }
        public String getReason() { return reason; }
        public void setReason(String reason) { this.reason = reason; }
    }

    public static class RouteData {
        private double distanceKm;
        private int durationMinutes;
        private List<LatLngDto> points;

        public RouteData() {}
        public RouteData(double distanceKm, int durationMinutes, List<LatLngDto> points) {
            this.distanceKm = distanceKm;
            this.durationMinutes = durationMinutes;
            this.points = points;
        }

        public double getDistanceKm() { return distanceKm; }
        public void setDistanceKm(double distanceKm) { this.distanceKm = distanceKm; }
        public int getDurationMinutes() { return durationMinutes; }
        public void setDurationMinutes(int durationMinutes) { this.durationMinutes = durationMinutes; }
        public List<LatLngDto> getPoints() { return points; }
        public void setPoints(List<LatLngDto> points) { this.points = points; }
    }
}
