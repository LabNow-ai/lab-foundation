CREATE OR REPLACE PROCEDURE enable_all_extensions()
LANGUAGE plpgsql
AS $$
DECLARE
    extension_name TEXT;
BEGIN
    FOR extension_name IN
        SELECT name FROM pg_available_extensions
        WHERE name NOT IN (SELECT extname AS name FROM pg_extension)
        ORDER BY name
    LOOP
        BEGIN
            EXECUTE format('CREATE EXTENSION IF NOT EXISTS %I', extension_name);
        EXCEPTION WHEN OTHERS THEN
            -- Optionally log the error or do nothing to continue with the next extension
            RAISE NOTICE 'Failed to create extension %: %', extension_name, SQLERRM;
        END;
    END LOOP;
END;
$$;

CREATE EXTENSION IF NOT EXISTS "hstore";
-- CALL enable_all_extensions();
