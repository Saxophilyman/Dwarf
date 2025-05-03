WITH product_stats AS (
    SELECT
        w.workshop_id,
        w.name AS workshop_name,
        w.type AS workshop_type,
        COUNT(DISTINCT wc.dwarf_id) AS num_craftsdwarves,
        COALESCE(SUM(p.value), 0) AS total_production_value,
        COALESCE(SUM(wp.quantity), 0) AS total_quantity_produced,
        ROUND(COALESCE(SUM(p.value), 0)::numeric / NULLIF(SUM(wp.quantity), 0), 2) AS average_product_value
    FROM
        workshops w
            LEFT JOIN workshop_craftsdwarves wc ON w.workshop_id = wc.workshop_id
            LEFT JOIN workshop_products wp ON w.workshop_id = wp.workshop_id
            LEFT JOIN products p ON wp.product_id = p.product_id
    GROUP BY
        w.workshop_id, w.name, w.type
),
     material_usage AS (
         SELECT
             wm.workshop_id,
             COALESCE(SUM(CASE WHEN wm.is_input THEN wm.quantity ELSE 0 END), 0) AS total_input_materials,
             COALESCE(SUM(CASE WHEN NOT wm.is_input THEN wm.quantity ELSE 0 END), 0) AS total_output_materials
         FROM workshop_materials wm
         GROUP BY wm.workshop_id
     ),
     skill_influence AS (
         SELECT
             wc.workshop_id,
             ROUND(AVG(ds.level)::numeric, 2) AS average_craftsdwarf_skill
         FROM
             workshop_craftsdwarves wc
                 JOIN dwarf_skills ds ON wc.dwarf_id = ds.dwarf_id
         GROUP BY wc.workshop_id
     ),
     final_stats AS (
         SELECT
             ps.workshop_id,
             ps.workshop_name,
             ps.workshop_type,
             ps.num_craftsdwarves,
             ps.total_quantity_produced,
             ps.total_production_value,
             ROUND(ps.total_quantity_produced::numeric / NULLIF(DATE_PART('day', CURRENT_DATE - MIN(wp.production_date)), 0), 2) AS daily_production_rate,
             ROUND(ps.total_production_value::numeric / NULLIF(mu.total_input_materials, 0), 2) AS value_per_material_unit,
             ROUND(mu.total_output_materials::numeric / NULLIF(mu.total_input_materials, 1), 2) AS material_conversion_ratio,
             si.average_craftsdwarf_skill,
             ROUND(CASE
                       WHEN si.average_craftsdwarf_skill > 0
                           THEN ps.average_product_value / si.average_craftsdwarf_skill
                       ELSE 0
                       END, 2) AS skill_quality_correlation
         FROM product_stats ps
                  LEFT JOIN material_usage mu ON ps.workshop_id = mu.workshop_id
                  LEFT JOIN skill_influence si ON ps.workshop_id = si.workshop_id
                  LEFT JOIN workshop_products wp ON ps.workshop_id = wp.workshop_id
         GROUP BY
             ps.workshop_id, ps.workshop_name, ps.workshop_type, ps.num_craftsdwarves,
             ps.total_quantity_produced, ps.total_production_value, ps.average_product_value,
             mu.total_input_materials, mu.total_output_materials, si.average_craftsdwarf_skill
     )
SELECT
    *,
    JSON_BUILD_OBJECT(
            'craftsdwarf_ids', (
        SELECT JSON_AGG(DISTINCT wc.dwarf_id)
        FROM workshop_craftsdwarves wc
        WHERE wc.workshop_id = fs.workshop_id
    ),
            'product_ids', (
                SELECT JSON_AGG(DISTINCT wp.product_id)
                FROM workshop_products wp
                WHERE wp.workshop_id = fs.workshop_id
            ),
            'material_ids', (
                SELECT JSON_AGG(DISTINCT wm.resource_id)
                FROM workshop_materials wm
                WHERE wm.workshop_id = fs.workshop_id
            ),
            'project_ids', (
                SELECT JSON_AGG(DISTINCT pr.project_id)
                FROM projects pr
                WHERE pr.workshop_id = fs.workshop_id
            )
    ) AS related_entities
FROM final_stats fs
ORDER BY total_production_value DESC;
