package com.example.otel_demo.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

@RestController
public class ErrorController {

    @GetMapping("/error-test")
    public String triggerError() {
        String errorId = UUID.randomUUID().toString();
        throw new RuntimeException("Intentional error for OTel demo [error-id=" + errorId + "]");
    }
}
