package com.travelgo.backend.map.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

public class LatLngDto {
    @JsonProperty("lat")
    private double lat;
    
    @JsonProperty("lng")
    private double lng;

    public LatLngDto() {}
    
    public LatLngDto(double lat, double lng) {
        this.lat = lat;
        this.lng = lng;
    }

    public double getLat() { return lat; }
    public void setLat(double lat) { this.lat = lat; }
    public double getLng() { return lng; }
    public void setLng(double lng) { this.lng = lng; }
}
