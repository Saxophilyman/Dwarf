-- Задача 2: Получение данных о гноме с навыками и назначениями
SELECT
    d.dwarf_id,
    d.name,
    d.age,
    d.profession,
    json_build_object(
            'skill_ids', (
        SELECT json_agg(ds.skill_id)
        FROM dwarf_skills ds
        WHERE ds.dwarf_id = d.dwarf_id
    ),
            'assignment_ids', (
                SELECT json_agg(da.assignment_id)
                FROM dwarf_assignments da
                WHERE da.dwarf_id = d.dwarf_id
            ),
            'squad_ids', (
                SELECT json_agg(sm.squad_id)
                FROM squad_members sm
                WHERE sm.dwarf_id = d.dwarf_id
            ),
            'equipment_ids', (
                SELECT json_agg(de.equipment_id)
                FROM dwarf_equipment de
                WHERE de.dwarf_id = d.dwarf_id
            )
    ) AS related_entities
FROM dwarves d
WHERE d.dwarf_id = 101;

-- Задача 3: Данные о мастерской с назначенными рабочими и проектами
SELECT
    w.workshop_id,
    w.name,
    w.type,
    w.quality,
    json_build_object(
            'craftsdwarf_ids', (
        SELECT json_agg(wc.dwarf_id)
        FROM workshop_craftsdwarves wc
        WHERE wc.workshop_id = w.workshop_id
    ),
            'project_ids', (
                SELECT json_agg(p.project_id)
                FROM projects p
                WHERE p.workshop_id = w.workshop_id
            ),
            'input_material_ids', (
                SELECT json_agg(wm.material_id)
                FROM workshop_materials wm
                WHERE wm.workshop_id = w.workshop_id AND wm.is_input = true
            ),
            'output_product_ids', (
                SELECT json_agg(wp.product_id)
                FROM workshop_products wp
                WHERE wp.workshop_id = w.workshop_id
            )
    ) AS related_entities
FROM workshops w
WHERE w.workshop_id = 301;

-- Задача 4: Данные о военном отряде с составом и операциями
SELECT
    s.squad_id,
    s.name,
    s.formation_type,
    s.leader_id,
    json_build_object(
            'member_ids', (
        SELECT json_agg(sm.dwarf_id)
        FROM squad_members sm
        WHERE sm.squad_id = s.squad_id
    ),
            'equipment_ids', (
                SELECT json_agg(se.equipment_id)
                FROM squad_equipment se
                WHERE se.squad_id = s.squad_id
            ),
            'operation_ids', (
                SELECT json_agg(so.operation_id)
                FROM squad_operations so
                WHERE so.squad_id = s.squad_id
            ),
            'training_schedule_ids', (
                SELECT json_agg(st.schedule_id)
                FROM squad_training st
                WHERE st.squad_id = s.squad_id
            ),
            'battle_report_ids', (
                SELECT json_agg(sb.report_id)
                FROM squad_battles sb
                WHERE sb.squad_id = s.squad_id
            )
    ) AS related_entities
FROM military_squads s
WHERE s.squad_id = 401;