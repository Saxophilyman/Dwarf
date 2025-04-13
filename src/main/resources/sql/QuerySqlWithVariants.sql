-- 1. Получить информацию о всех гномах, которые входят в какой-либо отряд, вместе с информацией об их отрядах.
SELECT d.dwarf_id,
       d.name AS dwarf_name,
       d.age,
       d.profession,
       s.squad_id,
       s.name AS squad_name,
       s.mission
FROM Dwarves d
         JOIN
     Squads s ON d.squad_id = s.squad_id;


SELECT *
FROM Dwarves
         JOIN Squads ON Dwarves.squad_id = Squads.squad_id;

-- 2. Найти всех гномов с профессией "miner", которые не состоят ни в одном отряде.
SELECT *
FROM Dwarves
WHERE profession = 'miner'
  AND squad_id IS NULL;

-- 3. Получить все задачи с наивысшим приоритетом, которые находятся в статусе "pending".
-- SELECT * FROM Tasks WHERE  status = 'pending' ORDER BY max(priority);
SELECT *
FROM Tasks
WHERE status = 'pending'
  AND priority = (SELECT MAX(priority)
                  FROM Tasks
                  WHERE status = 'pending');

-- 4. Для каждого гнома, который владеет хотя бы одним предметом, получить количество предметов, которыми он владеет.
-- SELECT count(item_id) FROM Items WHERE items.owner_id IS NOT NULL;
SELECT d.dwarf_id,
       d.name,
       COUNT(i.item_id) AS item_count
FROM Dwarves d
         JOIN
     Items i ON d.dwarf_id = i.owner_id
GROUP BY d.dwarf_id, d.name;


-- 5. Получить список всех отрядов и количество гномов в каждом отряде. Также включите в выдачу отряды без гномов.
SELECT s.squad_id, s.name, count(d.dwarf_id) dwarf_count
FROM Squads s
         LEFT JOIN
     Dwarves d ON s.squad_id = d.squad_id
GROUP BY s.squad_id, s.name;

-- 6. Получить список профессий с наибольшим количеством незавершённых задач ("pending" и "in_progress") у гномов этих профессий.
WITH TaskCountsByProfession AS (SELECT d.profession,
                                       COUNT(*) AS task_count
                                FROM Dwarves d
                                         JOIN
                                     Tasks t ON d.dwarf_id = t.assigned_to
                                WHERE t.status IN ('pending', 'in_progress')
                                GROUP BY d.profession),
     MaxCount AS (SELECT MAX(task_count) AS max_task_count
                  FROM TaskCountsByProfession)
SELECT p.profession,
       p.task_count
FROM TaskCountsByProfession p,
     MaxCount m
WHERE p.task_count = m.max_task_count;

-- 7. Для каждого типа предметов узнать средний возраст гномов, владеющих этими предметами.
-- (получилось)
SELECT i.type, avg(d.age)
FROM items i
         LEFT JOIN dwarves d
                   ON i.owner_id = d.dwarf_id
WHERE d.age IS NOT NULL
group by i.type;

-- 8. Найти всех гномов старше среднего возраста (по всем гномам в базе), которые не владеют никакими предметами.
-- SELECT d.dwarf_id, d.name
-- FROM dwarves d
--          LEFT OUTER JOIN items i ON d.dwarf_id = i.owner_id
-- HAVING age > avg(age);
SELECT d.dwarf_id, d.name, d.age
FROM Dwarves d
         LEFT JOIN Items i ON d.dwarf_id = i.owner_id
WHERE i.item_id IS NULL
  AND d.age > (
    SELECT AVG(age) FROM Dwarves
);
