-- 1. Найдите все отряды, у которых нет лидера.
--
SELECT s.squad_id, s.name
FROM squads s
WHERE s.leader_id IS NULL;


-- 2. Получите список всех гномов старше 150 лет, у которых профессия "Warrior".
--
SELECT d.dwarf_id, d.name, d.age, d.profession
FROM dwarves d
WHERE profession = 'Warrior'
  AND d.age > 150;

-- 3. Найдите гномов, у которых есть хотя бы один предмет типа "weapon".
--
SELECT DISTINCT d.dwarf_id, d.name, d.age, d.profession
FROM dwarves d
         JOIN items i ON d.dwarf_id = i.owner_id
WHERE i.type = 'weapon';

-- 4. Получите количество задач для каждого гнома, сгруппировав их по статусу.
--

--     SELECT d.dwarf_id, d.name, count(t.assigned_to) as tasks, t.status
--         FROM dwarves d
--             JOIN tasks t ON d.dwarf_id = t.assigned_to
--             GROUP BY d.dwarf_id, t.status;

SELECT d.dwarf_id,
       d.name,
       t.status,
       COUNT(t.task_id) AS task_count
FROM dwarves d
         LEFT JOIN
     tasks t ON d.dwarf_id = t.assigned_to
GROUP BY d.dwarf_id, d.name, t.status
ORDER BY d.dwarf_id, t.status;

-- 5. Найдите все задачи, которые были назначены гномам из отряда с именем "Guardians".
--
SELECT t.task_id, t.description
FROM tasks t
         JOIN dwarves d ON t.assigned_to = d.dwarf_id
         JOIN squads s ON d.squad_id = s.squad_id
WHERE s.name = 'Guardians';

-- 6. Выведите всех гномов и их ближайших родственников, указав тип родственных отношений.
SELECT
    g1.dwarf_id     AS dwarf_id,
    g1.name         AS dwarf_name,
    g2.dwarf_id     AS relative_id,
    g2.name         AS relative_name,
    r.relationship
FROM
    Relationships r
        JOIN Dwarves g1 ON r.dwarf_id = g1.dwarf_id
        JOIN Dwarves g2 ON r.related_to = g2.dwarf_id
WHERE
    r.relationship IN ('Супруг', 'Родитель', 'Ребёнок');

