-- ============================================
-- FIX RLS POLICIES FOR BUILDINGS, FLOORS, AND ROOMS
-- ============================================
-- Adds missing RLS policies for physical structure tables

-- ============================================
-- BUILDINGS TABLE
-- ============================================

-- Enable RLS if not already enabled
ALTER TABLE IF EXISTS buildings ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "authenticated_read_buildings" ON buildings;
DROP POLICY IF EXISTS "admins_manage_buildings" ON buildings;

-- All authenticated users can read buildings in their school
CREATE POLICY "authenticated_read_buildings" ON buildings
    FOR SELECT TO authenticated
    USING (
        school_id IN (SELECT school_id FROM users WHERE id = auth.uid())
        OR public.get_my_role() IN ('admin', 'staff')
    );

-- Only admins can insert, update, delete buildings
CREATE POLICY "admins_manage_buildings" ON buildings
    FOR ALL TO authenticated
    USING (public.get_my_role() IN ('admin', 'staff'))
    WITH CHECK (public.get_my_role() IN ('admin', 'staff'));

-- ============================================
-- FLOORS TABLE
-- ============================================

-- Enable RLS if not already enabled
ALTER TABLE IF EXISTS floors ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "authenticated_read_floors" ON floors;
DROP POLICY IF EXISTS "admins_manage_floors" ON floors;

-- All authenticated users can read floors
CREATE POLICY "authenticated_read_floors" ON floors
    FOR SELECT TO authenticated
    USING (
        building_id IN (
            SELECT id FROM buildings 
            WHERE school_id IN (SELECT school_id FROM users WHERE id = auth.uid())
        )
        OR public.get_my_role() IN ('admin', 'staff')
    );

-- Only admins can insert, update, delete floors
CREATE POLICY "admins_manage_floors" ON floors
    FOR ALL TO authenticated
    USING (public.get_my_role() IN ('admin', 'staff'))
    WITH CHECK (public.get_my_role() IN ('admin', 'staff'));

-- ============================================
-- ROOMS TABLE
-- ============================================

-- Enable RLS if not already enabled
ALTER TABLE IF EXISTS rooms ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "authenticated_read_rooms" ON rooms;
DROP POLICY IF EXISTS "admins_manage_rooms" ON rooms;

-- All authenticated users can read rooms
CREATE POLICY "authenticated_read_rooms" ON rooms
    FOR SELECT TO authenticated
    USING (
        floor_id IN (
            SELECT f.id FROM floors f
            JOIN buildings b ON f.building_id = b.id
            WHERE b.school_id IN (SELECT school_id FROM users WHERE id = auth.uid())
        )
        OR public.get_my_role() IN ('admin', 'staff')
    );

-- Only admins can insert, update, delete rooms
CREATE POLICY "admins_manage_rooms" ON rooms
    FOR ALL TO authenticated
    USING (public.get_my_role() IN ('admin', 'staff'))
    WITH CHECK (public.get_my_role() IN ('admin', 'staff'));
