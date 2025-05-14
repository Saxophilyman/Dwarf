WITH trade_base AS (
    SELECT
        c.caravan_id,
        c.civilization_type,
        c.arrival_date,
        tt.value AS net_trade_value,
        tt.fortress_items,
        tt.caravan_items,
        (tt.fortress_items - tt.caravan_items) AS trade_balance,
        EXTRACT(YEAR FROM c.arrival_date) AS year,
        EXTRACT(QUARTER FROM c.arrival_date) AS quarter
    FROM trade_transactions tt
             JOIN caravans c ON c.caravan_id = tt.caravan_id
),
-- Общая торговая статистика
     global_trade AS (
         SELECT
             COUNT(DISTINCT tb.civilization_type) AS total_trading_partners,
             SUM(tb.fortress_items + tb.caravan_items) AS all_time_trade_value,
             SUM(tb.trade_balance) AS all_time_trade_balance
         FROM trade_base tb
     ),
-- Торговля по цивилизациям
     civilization_trade AS (
         SELECT
             tb.civilization_type,
             COUNT(DISTINCT tb.caravan_id) AS total_caravans,
             SUM(tb.fortress_items + tb.caravan_items) AS total_trade_value,
             SUM(tb.trade_balance) AS trade_balance,
             CASE
                 WHEN SUM(tb.trade_balance) > 0 THEN 'Favorable'
                 ELSE 'Unfavorable'
                 END AS trade_relationship,
             (SELECT
                  CORR(tt.value::DOUBLE PRECISION,
                       CASE
                           WHEN de.outcome = 'Alliance' THEN 1
                           WHEN de.outcome = 'Trade Agreement' THEN 0.5
                           ELSE 0
                           END)
              FROM trade_transactions tt
                       JOIN diplomatic_events de ON tt.caravan_id = de.caravan_id
                       JOIN caravans c ON c.caravan_id = tt.caravan_id
              WHERE c.civilization_type = tb.civilization_type
             ) AS diplomatic_correlation,
             ARRAY_AGG(DISTINCT tb.caravan_id) AS caravan_ids
         FROM trade_base tb
         GROUP BY tb.civilization_type
     ),
-- Зависимость от импортируемых материалов
     material_dependency AS (
         SELECT
             cg.material_type,
             SUM(cg.quantity) AS total_imported,
             COUNT(DISTINCT cg.name) AS import_diversity, -- по названию ресурса
             SUM(cg.quantity * cg.value) / NULLIF(COUNT(DISTINCT cg.name), 0) AS dependency_score,
             ARRAY_AGG(DISTINCT cg.name) AS resource_names
         FROM caravan_goods cg
         WHERE cg.type = 'Import'
         GROUP BY cg.material_type
     ),
-- Эффективность экспорта продукции мастерских
     export_effectiveness_raw AS (
         SELECT
             w.type AS workshop_type,
             p.type AS product_type,
             COUNT(DISTINCT w.workshop_id) AS workshop_count,
             COUNT(*) FILTER (WHERE cg.goods_id IS NOT NULL) * 100.0 / COUNT(*) AS export_ratio,
             AVG(cg.value / NULLIF(p.value, 0)) AS avg_markup,
             ARRAY_AGG(DISTINCT w.workshop_id) AS workshop_ids
         FROM workshop_products wp
                  JOIN products p ON p.product_id = wp.product_id
                  JOIN workshops w ON wp.workshop_id = w.workshop_id
                  LEFT JOIN caravan_goods cg ON cg.original_product_id = p.product_id
         GROUP BY w.type, p.type
     ),
-- Хронология торговли
     quarterly_trade AS (
         SELECT
             tb.year,
             tb.quarter,
             SUM(tb.fortress_items + tb.caravan_items) AS quarterly_value,
             SUM(tb.trade_balance) AS quarterly_balance,
             COUNT(DISTINCT tb.civilization_type) AS trade_diversity
         FROM trade_base tb
         GROUP BY tb.year, tb.quarter
     )
-- Финальный JSON
SELECT JSON_BUILD_OBJECT(
               'total_trading_partners', gt.total_trading_partners,
               'all_time_trade_value', gt.all_time_trade_value,
               'all_time_trade_balance', gt.all_time_trade_balance,

               'civilization_data', JSON_BUILD_OBJECT(
                       'civilization_trade_data', JSON_AGG(
                        JSON_BUILD_OBJECT(
                                'civilization_type', ct.civilization_type,
                                'total_caravans', ct.total_caravans,
                                'total_trade_value', ct.total_trade_value,
                                'trade_balance', ct.trade_balance,
                                'trade_relationship', ct.trade_relationship,
                                'diplomatic_correlation', ROUND(ct.diplomatic_correlation, 2),
                                'caravan_ids', ct.caravan_ids
                        )
                                                  )
                                    ),

               'critical_import_dependencies', JSON_BUILD_OBJECT(
                       'resource_dependency', JSON_AGG(
                        JSON_BUILD_OBJECT(
                                'material_type', md.material_type,
                                'dependency_score', ROUND(md.dependency_score, 2),
                                'total_imported', md.total_imported,
                                'import_diversity', md.import_diversity,
                                'resource_names', md.resource_names
                        )
                                              )
                                               ),

               'export_effectiveness', JSON_BUILD_OBJECT(
                       'export_effectiveness', JSON_AGG(
                        JSON_BUILD_OBJECT(
                                'workshop_type', eer.workshop_type,
                                'product_type', eer.product_type,
                                'export_ratio', ROUND(eer.export_ratio, 2),
                                'avg_markup', ROUND(eer.avg_markup, 2),
                                'workshop_ids', eer.workshop_ids
                        )
                                               )
                                       ),

               'trade_timeline', JSON_BUILD_OBJECT(
                       'trade_growth', JSON_AGG(
                        JSON_BUILD_OBJECT(
                                'year', qt.year,
                                'quarter', qt.quarter,
                                'quarterly_value', qt.quarterly_value,
                                'quarterly_balance', qt.quarterly_balance,
                                'trade_diversity', qt.trade_diversity
                        )
                        ORDER BY qt.year, qt.quarter)
                                 )
       )
FROM
    global_trade gt,
    civilization_trade ct,
    material_dependency md,
    export_effectiveness_raw eer,
    quarterly_trade qt;
