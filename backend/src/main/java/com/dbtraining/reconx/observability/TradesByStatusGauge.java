package com.dbtraining.reconx.observability;

import com.dbtraining.reconx.repository.TradeRepository;
import io.micrometer.core.instrument.Gauge;
import io.micrometer.core.instrument.MeterRegistry;
import org.springframework.stereotype.Component;

import java.util.List;

@Component
public class TradesByStatusGauge {

    public TradesByStatusGauge(MeterRegistry registry,
                               TradeRepository tradeRepository) {

        List<String> statuses = List.of(
                "PENDING",
                "MATCHED",
                "UNMATCHED",
                "DISPUTED",
                "CANCELLED"
        );

        for (String status : statuses) {

            Gauge.builder(
                    "trades_by_status",
                    tradeRepository,
                    repo -> repo.countByStatus(status)
            )
                    .description("Trades currently in a given status")
                    .tag("status", status)
                    .register(registry);
        }
    }
}
