--liquibase formatted sql

--changeset init:1
-- Миграция содержит текущую структуру базы, чтобы Liquibase начал отслеживание с неё
-- Эту миграцию НЕ нужно применять — нужно выполнить liquibase changelogSync

-- Исходная структура базы уже вручную создана
-- Liquibase будет считать, что она уже применена
