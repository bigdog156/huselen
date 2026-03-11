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
