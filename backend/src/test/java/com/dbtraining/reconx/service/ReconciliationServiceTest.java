package com.dbtraining.reconx.service;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class ReconciliationServiceTest {

    @Test
    void engineCanBeCreated() {
        ReconciliationEngine engine = new ReconciliationEngine();
        assertThat(engine).isNotNull();
    }
}
