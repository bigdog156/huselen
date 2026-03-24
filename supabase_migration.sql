-- ============================================================
-- Supabase Migration for Huselen Gym Management App
-- Run this in the Supabase SQL editor
-- ============================================================

-- PROFILES (public profile linked to auth.users)
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT DEFAULT '',
    phone TEXT DEFAULT '',
    avatar_url TEXT DEFAULT '',
    email TEXT DEFAULT '',
    username TEXT DEFAULT '',
    role TEXT DEFAULT 'client',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own profile" ON profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON profiles FOR ALL USING (auth.uid() = id);

-- PT PACKAGES (training packages)
CREATE TABLE IF NOT EXISTS pt_packages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    total_sessions INT DEFAULT 0,
    price DOUBLE PRECISION DEFAULT 0,
    duration_days INT DEFAULT 30,
    description TEXT DEFAULT '',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE pt_packages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Owners manage packages" ON pt_packages FOR ALL USING (auth.uid() = owner_id);

-- TRAINERS (gym-local trainer records linked to profiles)
CREATE TABLE IF NOT EXISTS trainers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    profile_id UUID REFERENCES profiles(id),
    name TEXT NOT NULL,
    phone TEXT DEFAULT '',
    specialization TEXT DEFAULT '',
    experience_years INT DEFAULT 0,
    bio TEXT DEFAULT '',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- CLIENTS (gym-local client records linked to profiles)
CREATE TABLE IF NOT EXISTS clients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    profile_id UUID REFERENCES profiles(id),
    name TEXT NOT NULL,
    phone TEXT DEFAULT '',
    email TEXT DEFAULT '',
    weight DOUBLE PRECISION DEFAULT 0,
    body_fat DOUBLE PRECISION DEFAULT 0,
    muscle_mass DOUBLE PRECISION DEFAULT 0,
    goal TEXT DEFAULT '',
    notes TEXT DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- PACKAGE PURCHASES
CREATE TABLE IF NOT EXISTS package_purchases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    purchase_id UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    package_id UUID REFERENCES pt_packages(id),
    trainer_id UUID REFERENCES trainers(id) ON DELETE SET NULL,
    client_id UUID REFERENCES clients(id) ON DELETE CASCADE,
    price DOUBLE PRECISION DEFAULT 0,
    total_sessions INT DEFAULT 0,
    purchase_date TIMESTAMPTZ DEFAULT now(),
    expiry_date TIMESTAMPTZ DEFAULT now(),
    notes TEXT DEFAULT '',
    schedule_days INT[] DEFAULT '{}',
    schedule_hour INT DEFAULT 18,
    schedule_minute INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- TRAINING SESSIONS
CREATE TABLE IF NOT EXISTS training_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    trainer_id UUID REFERENCES trainers(id) ON DELETE SET NULL,
    client_id UUID REFERENCES clients(id) ON DELETE CASCADE,
    purchase_id UUID,
    scheduled_date TIMESTAMPTZ NOT NULL,
    duration INT DEFAULT 60,
    is_completed BOOLEAN DEFAULT FALSE,
    is_checked_in BOOLEAN DEFAULT FALSE,
    check_in_time TIMESTAMPTZ,
    notes TEXT DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- INDEXES
CREATE INDEX IF NOT EXISTS idx_trainers_owner ON trainers(owner_id);
CREATE INDEX IF NOT EXISTS idx_clients_owner ON clients(owner_id);
CREATE INDEX IF NOT EXISTS idx_training_sessions_owner ON training_sessions(owner_id);
CREATE INDEX IF NOT EXISTS idx_training_sessions_scheduled ON training_sessions(scheduled_date);
CREATE INDEX IF NOT EXISTS idx_package_purchases_owner ON package_purchases(owner_id);
CREATE INDEX IF NOT EXISTS idx_package_purchases_client ON package_purchases(client_id);

-- ROW LEVEL SECURITY
ALTER TABLE trainers ENABLE ROW LEVEL SECURITY;
ALTER TABLE clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE package_purchases ENABLE ROW LEVEL SECURITY;
ALTER TABLE training_sessions ENABLE ROW LEVEL SECURITY;

-- Owners can manage their own records
CREATE POLICY "Owners manage trainers" ON trainers FOR ALL USING (auth.uid() = owner_id);
CREATE POLICY "Owners manage clients" ON clients FOR ALL USING (auth.uid() = owner_id);
CREATE POLICY "Owners manage purchases" ON package_purchases FOR ALL USING (auth.uid() = owner_id);
CREATE POLICY "Owners manage sessions" ON training_sessions FOR ALL USING (auth.uid() = owner_id);

-- Trainers can view sessions assigned to them
CREATE POLICY "Trainers view their sessions" ON training_sessions FOR SELECT
USING (
    trainer_id IN (SELECT id FROM trainers WHERE profile_id = auth.uid())
);

-- Clients can view sessions assigned to them
CREATE POLICY "Clients view their sessions" ON training_sessions FOR SELECT
USING (
    client_id IN (SELECT id FROM clients WHERE profile_id = auth.uid())
);

-- Clients can view their purchases
CREATE POLICY "Clients view their purchases" ON package_purchases FOR SELECT
USING (
    client_id IN (SELECT id FROM clients WHERE profile_id = auth.uid())
);

-- Clients can read trainers assigned to their sessions
CREATE POLICY "Clients read their trainers" ON trainers FOR SELECT
USING (
    id IN (
        SELECT trainer_id FROM training_sessions
        WHERE client_id IN (SELECT id FROM clients WHERE profile_id = auth.uid())
    )
);

-- Trainers can read clients assigned to their sessions
CREATE POLICY "Trainers read their clients" ON clients FOR SELECT
USING (
    id IN (
        SELECT client_id FROM training_sessions
        WHERE trainer_id IN (SELECT id FROM trainers WHERE profile_id = auth.uid())
    )
);

-- Updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_profiles_updated_at BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER set_pt_packages_updated_at BEFORE UPDATE ON pt_packages FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER set_trainers_updated_at BEFORE UPDATE ON trainers FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER set_clients_updated_at BEFORE UPDATE ON clients FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER set_purchases_updated_at BEFORE UPDATE ON package_purchases FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER set_sessions_updated_at BEFORE UPDATE ON training_sessions FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- Migration: Add makeup session support
-- ============================================================
ALTER TABLE training_sessions ADD COLUMN IF NOT EXISTS is_makeup BOOLEAN DEFAULT FALSE;
ALTER TABLE training_sessions ADD COLUMN IF NOT EXISTS original_session_id UUID REFERENCES training_sessions(id);

-- ============================================================
-- Migration: RLS policies for Trainer (PT) role
-- ============================================================

-- Trainers can read their own trainer record
CREATE POLICY "Trainers read own record" ON trainers FOR SELECT
USING (profile_id = auth.uid());

-- Trainers can read purchases assigned to them
CREATE POLICY "Trainers read their purchases" ON package_purchases FOR SELECT
USING (
    trainer_id IN (SELECT id FROM trainers WHERE profile_id = auth.uid())
);

-- Trainers can read packages linked to their purchases
CREATE POLICY "Trainers read packages" ON pt_packages FOR SELECT
USING (
    id IN (
        SELECT package_id FROM package_purchases
        WHERE trainer_id IN (SELECT id FROM trainers WHERE profile_id = auth.uid())
    )
);

-- Trainers can INSERT sessions (for makeup sessions)
CREATE POLICY "Trainers create sessions" ON training_sessions FOR INSERT
WITH CHECK (
    trainer_id IN (SELECT id FROM trainers WHERE profile_id = auth.uid())
);

-- Trainers can UPDATE their own sessions
CREATE POLICY "Trainers update their sessions" ON training_sessions FOR UPDATE
USING (
    trainer_id IN (SELECT id FROM trainers WHERE profile_id = auth.uid())
);

-- Trainer attendance: enable RLS and add policies
ALTER TABLE trainer_attendance ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Owners manage attendance" ON trainer_attendance FOR ALL
USING (auth.uid() IN (SELECT owner_id FROM trainers WHERE id = trainer_id));

CREATE POLICY "Trainers manage own attendance" ON trainer_attendance FOR ALL
USING (
    trainer_id IN (SELECT id FROM trainers WHERE profile_id = auth.uid())
);

-- ============================================================
-- Migration: Multi-gym support
-- ============================================================

-- Gyms table: each admin owns one gym
CREATE TABLE IF NOT EXISTS gyms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    address TEXT DEFAULT '',
    phone TEXT DEFAULT '',
    logo_url TEXT DEFAULT '',
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    invite_code TEXT UNIQUE DEFAULT encode(gen_random_bytes(4), 'hex'),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE gyms ENABLE ROW LEVEL SECURITY;

-- Anyone authenticated can view gyms (needed for search/join flow)
CREATE POLICY "Authenticated users can view gyms" ON gyms FOR SELECT
USING (auth.role() = 'authenticated');

-- Only the owner can insert/update/delete their gym
CREATE POLICY "Owners manage their gym" ON gyms FOR INSERT
WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "Owners update their gym" ON gyms FOR UPDATE
USING (auth.uid() = owner_id);

CREATE POLICY "Owners delete their gym" ON gyms FOR DELETE
USING (auth.uid() = owner_id);

-- Add gym_id to profiles for user-gym association
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS gym_id UUID REFERENCES gyms(id);

-- Trigger for gyms updated_at
CREATE TRIGGER set_gyms_updated_at BEFORE UPDATE ON gyms FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- Migration: Meal Logs (MealLogView)
-- ============================================================

-- USER MEAL LOGS: stores daily meal entries per user
CREATE TABLE IF NOT EXISTS user_meal_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    meal_type TEXT NOT NULL CHECK (meal_type IN ('breakfast', 'lunch', 'afternoon', 'dinner')),
    logged_date DATE NOT NULL,
    logged_time TEXT,                        -- HH:mm:ss string
    photo_url TEXT,
    note TEXT,
    feeling TEXT CHECK (feeling IN ('good', 'normal', 'tired')),
    energy_level TEXT,
    calories INTEGER,
    protein_g DOUBLE PRECISION,
    carbs_g DOUBLE PRECISION,
    fat_g DOUBLE PRECISION,
    fiber_g DOUBLE PRECISION,
    food_items JSONB,                        -- array of MealLogFoodItem
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (user_id, meal_type, logged_date) -- one log per meal per day per user
);

-- Indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_user_meal_logs_user ON user_meal_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_user_meal_logs_date ON user_meal_logs(logged_date);
CREATE INDEX IF NOT EXISTS idx_user_meal_logs_user_date ON user_meal_logs(user_id, logged_date);

-- Row Level Security
ALTER TABLE user_meal_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own meal logs" ON user_meal_logs FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Updated_at trigger
CREATE TRIGGER set_user_meal_logs_updated_at
BEFORE UPDATE ON user_meal_logs
FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- Storage: meal-photos bucket
-- ============================================================
-- Run these in the Supabase Dashboard > Storage, or via SQL:

INSERT INTO storage.buckets (id, name, public)
VALUES ('meal-photos', 'meal-photos', true)
ON CONFLICT (id) DO NOTHING;

-- Users can upload to their own folder (userId/...)
CREATE POLICY "Users upload own meal photos" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
    bucket_id = 'meal-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Users can update/delete their own photos
CREATE POLICY "Users manage own meal photos" ON storage.objects
FOR ALL TO authenticated
USING (
    bucket_id = 'meal-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Anyone can read photos (bucket is public, but explicit SELECT policy)
CREATE POLICY "Public read meal photos" ON storage.objects
FOR SELECT
USING (bucket_id = 'meal-photos');

-- ============================================================
-- meal_comments: PT/Admin feedback on client daily meals
-- ============================================================

CREATE TABLE IF NOT EXISTS meal_comments (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    meal_log_id   UUID REFERENCES user_meal_logs(id) ON DELETE CASCADE,
    client_id     UUID NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
    comment_date  DATE NOT NULL,
    author_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    author_name   TEXT NOT NULL,
    author_role   TEXT NOT NULL CHECK (author_role IN ('pt', 'admin')),
    message       TEXT NOT NULL,
    created_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS meal_comments_client_date_idx
    ON meal_comments (client_id, comment_date);

-- RLS: trainers and admins of the same gym can read/write
ALTER TABLE meal_comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Gym staff can manage meal comments"
ON meal_comments
FOR ALL
TO authenticated
USING (
    -- Author can always access their own comments
    author_id = auth.uid()
    OR
    -- Gym owner (admin) can access all comments for their clients
    client_id IN (
        SELECT id FROM clients WHERE owner_id = auth.uid()
    )
    OR
    -- Trainers can access comments for their assigned clients
    client_id IN (
        SELECT DISTINCT s.client_id
        FROM training_sessions s
        JOIN trainers t ON t.id = s.trainer_id
        WHERE t.profile_id = auth.uid()
    )
)
WITH CHECK (
    author_id = auth.uid()
);
