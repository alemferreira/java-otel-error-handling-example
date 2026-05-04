package com.example.otel_demo.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class ErrorController {

    @GetMapping("/error-test")
    public String triggerError() {
        throw new RuntimeException("Intentional error for OTel demo");
    }
}
