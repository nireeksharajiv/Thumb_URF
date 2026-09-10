-- =============================================================================
-- Migration: 001_initial_schema.sql
-- Description: Initial schema for Thumb Biomechanics Monitor Glove.
-- Tables: profiles, monitoring_sessions, sensor_readings
-- Includes: Foreign keys, cascade rules, indexes, RLS policies, and profile trigger.
-- =============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- -----------------------------------------------------------------------------
-- 1. PROFILES TABLE
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.profiles IS 'User profile metadata corresponding 1:1 with auth.users.';

-- -----------------------------------------------------------------------------
-- 2. MONITORING_SESSIONS TABLE
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.monitoring_sessions (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    started_at TIMESTAMPTZ NOT NULL,
    ended_at TIMESTAMPTZ,
    duration_seconds INTEGER NOT NULL DEFAULT 0,
    movement_count INTEGER NOT NULL DEFAULT 0,
    average_ip_angle DOUBLE PRECISION,
    max_ip_angle DOUBLE PRECISION,
    average_mcp_angle DOUBLE PRECISION,
    max_mcp_angle DOUBLE PRECISION,
    average_force DOUBLE PRECISION,
    peak_force DOUBLE PRECISION,
    average_angular_velocity DOUBLE PRECISION,
    average_motion_magnitude DOUBLE PRECISION,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.monitoring_sessions IS 'Completed biomechanical monitoring sessions with summarized metrics.';

-- -----------------------------------------------------------------------------
-- 3. SENSOR_READINGS TABLE
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.sensor_readings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES public.monitoring_sessions(id) ON DELETE CASCADE,
    timestamp TIMESTAMPTZ NOT NULL,
    ip_angle DOUBLE PRECISION,
    mcp_angle DOUBLE PRECISION,
    force DOUBLE PRECISION,
    angular_velocity DOUBLE PRECISION,
    motion_magnitude DOUBLE PRECISION
);

COMMENT ON TABLE public.sensor_readings IS 'High-frequency time-series biomechanical sensor readings attached to a session.';

-- -----------------------------------------------------------------------------
-- 4. PERFORMANCE INDEXES
-- -----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_monitoring_sessions_user_id
    ON public.monitoring_sessions(user_id);

CREATE INDEX IF NOT EXISTS idx_monitoring_sessions_started_at
    ON public.monitoring_sessions(started_at DESC);

CREATE INDEX IF NOT EXISTS idx_sensor_readings_session_id
    ON public.sensor_readings(session_id);

CREATE INDEX IF NOT EXISTS idx_sensor_readings_timestamp
    ON public.sensor_readings(timestamp ASC);

-- -----------------------------------------------------------------------------
-- 5. ROW LEVEL SECURITY (RLS)
-- -----------------------------------------------------------------------------
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.monitoring_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sensor_readings ENABLE ROW LEVEL SECURITY;

-- Profiles Policies
CREATE POLICY "Users can read own profile"
    ON public.profiles
    FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
    ON public.profiles
    FOR INSERT
    WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update own profile"
    ON public.profiles
    FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- Monitoring Sessions Policies
CREATE POLICY "Users can read own sessions"
    ON public.monitoring_sessions
    FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own sessions"
    ON public.monitoring_sessions
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own sessions"
    ON public.monitoring_sessions
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own sessions"
    ON public.monitoring_sessions
    FOR DELETE
    USING (auth.uid() = user_id);

-- Sensor Readings Policies
CREATE POLICY "Users can read sensor readings of own sessions"
    ON public.sensor_readings
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.monitoring_sessions ms
            WHERE ms.id = sensor_readings.session_id
              AND ms.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can insert sensor readings to own sessions"
    ON public.sensor_readings
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.monitoring_sessions ms
            WHERE ms.id = sensor_readings.session_id
              AND ms.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete sensor readings of own sessions"
    ON public.sensor_readings
    FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM public.monitoring_sessions ms
            WHERE ms.id = sensor_readings.session_id
              AND ms.user_id = auth.uid()
        )
    );

-- -----------------------------------------------------------------------------
-- 6. AUTOMATIC PROFILE CREATION TRIGGER
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.profiles (id, display_name, created_at)
    VALUES (
        new.id,
        COALESCE(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1)),
        now()
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();
