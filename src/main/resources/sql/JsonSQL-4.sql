WITH battle_stats AS (
    SELECT
        sb.squad_id,
        COUNT(sb.report_id) AS total_battles,
        COUNT(*) FILTER (WHERE sb.outcome = 'Victory') AS victories,
        SUM(sb.casualties) AS total_casualties,
        SUM(sb.enemy_casualties) AS total_enemy_casualties
    FROM squad_battles sb
    GROUP BY sb.squad_id
),
     skill_progress AS (
         SELECT
             sm.squad_id,
             AVG(ds.level) AS avg_skill_level,
             AVG(ds.level - LAG(ds.level) OVER (PARTITION BY ds.dwarf_id ORDER BY ds.date)) AS avg_skill_improvement
         FROM squad_members sm
                  JOIN dwarf_skills ds ON sm.dwarf_id = ds.dwarf_id
         GROUP BY sm.squad_id, sm.dwarf_id
     ),
     equipment_quality AS (
         SELECT
             se.squad_id,
             AVG(e.quality) AS avg_equipment_quality
         FROM squad_equipment se
                  JOIN equipment e ON se.equipment_id = e.equipment_id
         GROUP BY se.squad_id
     ),
     training_stats AS (
         SELECT
             st.squad_id,
             COUNT(st.schedule_id) AS total_training_sessions,
             AVG(st.effectiveness) AS avg_training_effectiveness
         FROM squad_training st
         GROUP BY st.squad_id
     ),
     retention_stats AS (
         SELECT
             sm.squad_id,
             COUNT(*) AS total_members_ever,
             COUNT(*) FILTER (WHERE sm.exit_date IS NULL) AS current_members
         FROM squad_members sm
         GROUP BY sm.squad_id
     ),
     training_battle_correlation_data AS (
         SELECT
             st.squad_id,
             st.date AS training_date,
             st.effectiveness,
             sb.date AS battle_date,
             CASE WHEN sb.outcome = 'Victory' THEN 1 ELSE 0 END AS is_victory
         FROM squad_training st
                  JOIN squad_battles sb ON st.squad_id = sb.squad_id
         WHERE sb.date >= st.date
     ),
     correlation_per_squad AS (
         SELECT
             squad_id,
             CORR(effectiveness::DOUBLE PRECISION, is_victory::DOUBLE PRECISION) AS training_battle_correlation
         FROM training_battle_correlation_data
         GROUP BY squad_id
     )
SELECT
    ms.squad_id,
    ms.name AS squad_name,
    ms.formation_type,
    d.name AS leader_name,

    bs.total_battles,
    bs.victories,
    ROUND(bs.victories::DECIMAL / NULLIF(bs.total_battles, 0) * 100, 2) AS victory_percentage,
    ROUND(bs.total_casualties::DECIMAL / NULLIF(bs.total_battles, 0), 2) AS casualty_rate,
    ROUND(bs.total_enemy_casualties::DECIMAL / NULLIF(bs.total_casualties, 0), 2) AS casualty_exchange_ratio,

    rs.current_members,
    rs.total_members_ever,
    ROUND(rs.current_members::DECIMAL / NULLIF(rs.total_members_ever, 0) * 100, 2) AS retention_rate,

    eq.avg_equipment_quality,
    ts.total_training_sessions,
    ts.avg_training_effectiveness,

    sp.avg_skill_level,
    sp.avg_skill_improvement,

    corr.training_battle_correlation,

    -- Итоговая оценка эффективности (гибкая формула, можно доработать)
    ROUND(
            (
                (bs.victories::DECIMAL / NULLIF(bs.total_battles, 0)) * 0.4 +
                (rs.current_members::DECIMAL / NULLIF(rs.total_members_ever, 0)) * 0.2 +
                (ts.avg_training_effectiveness) * 0.2 +
                (sp.avg_skill_improvement) * 0.2
                ), 3
    ) AS overall_effectiveness_score,

    -- JSON со связанными сущностями
    JSON_BUILD_OBJECT(
            'member_ids', (SELECT JSON_AGG(sm.dwarf_id) FROM squad_members sm WHERE sm.squad_id = ms.squad_id),
            'equipment_ids', (SELECT JSON_AGG(se.equipment_id) FROM squad_equipment se WHERE se.squad_id = ms.squad_id),
            'battle_report_ids', (SELECT JSON_AGG(sb.report_id) FROM squad_battles sb WHERE sb.squad_id = ms.squad_id),
            'training_ids', (SELECT JSON_AGG(st.schedule_id) FROM squad_training st WHERE st.squad_id = ms.squad_id)
    ) AS related_entities

FROM military_squads ms
         LEFT JOIN dwarves d ON ms.leader_id = d.dwarf_id
         LEFT JOIN battle_stats bs ON ms.squad_id = bs.squad_id
         LEFT JOIN skill_progress sp ON ms.squad_id = sp.squad_id
         LEFT JOIN equipment_quality eq ON ms.squad_id = eq.squad_id
         LEFT JOIN training_stats ts ON ms.squad_id = ts.squad_id
         LEFT JOIN retention_stats rs ON ms.squad_id = rs.squad_id
         LEFT JOIN correlation_per_squad corr ON ms.squad_id = corr.squad_id
ORDER BY overall_effectiveness_score DESC;
