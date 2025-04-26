WITH survival AS (
    SELECT
        em.expedition_id,
        COUNT(*) FILTER (WHERE em.survived) * 100.0 / NULLIF(COUNT(*), 0) AS survival_rate
    FROM expedition_members em
    GROUP BY em.expedition_id
),
     artifact_counts AS (
         SELECT
             ea.expedition_id,
             COUNT(ea.artifact_id) AS artifacts_found
         FROM expedition_artifacts ea
         GROUP BY ea.expedition_id
     ),
     discovered_sites AS (
         SELECT
             es.expedition_id,
             COUNT(es.site_id) AS site_count
         FROM expedition_sites es
         GROUP BY es.expedition_id
     ),
     encounters AS (
         SELECT
             ec.expedition_id,
             COUNT(*) FILTER (WHERE ec.outcome = 'success') * 100.0 / NULLIF(COUNT(*), 0) AS encounter_success_rate
         FROM expedition_creatures ec
         GROUP BY ec.expedition_id
     ),
     related_entities AS (
         SELECT
             e.expedition_id,
             json_build_object(
                     'member_ids', (SELECT json_agg(em.dwarf_id) FROM expedition_members em WHERE em.expedition_id = e.expedition_id),
                     'artifact_ids', (SELECT json_agg(ea.artifact_id) FROM expedition_artifacts ea WHERE ea.expedition_id = e.expedition_id),
                     'site_ids', (SELECT json_agg(es.site_id) FROM expedition_sites es WHERE es.expedition_id = e.expedition_id)
             ) AS related
         FROM expeditions e
     )
SELECT
    e.expedition_id,
    e.destination,
    e.status,
    COALESCE(s.survival_rate, 0) AS survival_rate,
    COALESCE(ac.artifacts_found, 0) * 1000 AS artifacts_value, -- просто примерная фиктивная стоимость
    COALESCE(ds.site_count, 0) AS discovered_sites,
    COALESCE(enc.encounter_success_rate, 0) AS encounter_success_rate,
    0 AS skill_improvement, -- Пока 0, потому что истории нет
    EXTRACT(DAY FROM (e.return_date - e.departure_date)) AS expedition_duration,

    -- Overall success score: Survival rate и Encounter success rate пополам
    ROUND((
              COALESCE(s.survival_rate, 0) + COALESCE(enc.encounter_success_rate, 0)
              ) / 200.0, 2) AS overall_success_score,

    r.related AS related_entities

FROM expeditions e
         LEFT JOIN survival s ON e.expedition_id = s.expedition_id
         LEFT JOIN artifact_counts ac ON e.expedition_id = ac.expedition_id
         LEFT JOIN discovered_sites ds ON e.expedition_id = ds.expedition_id
         LEFT JOIN encounters enc ON e.expedition_id = enc.expedition_id
         LEFT JOIN related_entities r ON e.expedition_id = r.expedition_id
WHERE e.status = 'Completed'
ORDER BY overall_success_score DESC;
