-- Supabase Migrations for LearnedFacts Feature

-- 1. Create learned_facts tableif not exists (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  category VARCHAR(50),
  confidence FLOAT DEFAULT 0.5,
  source VARCHAR(50) DEFAULT 'chat_history',
  extracted_at TIMESTAMP DEFAULT NOW(),
  last_used_in_chat TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  
  CONSTRAINT valid_confidence CHECK (confidence >= 0 AND confidence <= 1),
  CONSTRAINT valid_category CHECK (category IN ('preference', 'pricing', 'location', 'availability', 'technical', 'other'))
);

-- Add indexes for faster queries
CREATE INDEX idx_learned_facts_user_id ON learned_facts(user_id);
CREATE INDEX idx_learned_facts_category ON learned_facts(category);
CREATE INDEX idx_learned_facts_created_at ON learned_facts(created_at DESC);

-- Enable RLS (Row Level Security)
ALTER TABLE learned_facts ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can only see their own facts
CREATE POLICY learned_facts_user_policy ON learned_facts
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY learned_facts_insert_policy ON learned_facts
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY learned_facts_update_policy ON learned_facts
  FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY learned_facts_delete_policy ON learned_facts
  FOR DELETE
  USING (auth.uid() = user_id);

-- 2. Optional: Add learned_facts_sync_log table for audit trail
CREATE TABLE IF NOT EXISTS learned_facts_sync_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  fact_id UUID REFERENCES learned_facts(id) ON DELETE CASCADE,
  device_id VARCHAR(255),
  synced_at TIMESTAMP DEFAULT NOW(),
  confirmed_by_user BOOLEAN DEFAULT FALSE,
  
  INDEX idx_sync_log_user_id (user_id),
  INDEX idx_sync_log_synced_at (synced_at DESC)
);

-- 3. Optinonal: Update profile table to track learning preferences
ALTER TABLE artist_profiles 
ADD COLUMN IF NOT EXISTS learning_enabled BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS auto_extract_facts BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS fact_approval_required BOOLEAN DEFAULT TRUE;

-- 4. Create a view for fact summaries (helpful for analytics)
CREATE OR REPLACE VIEW learned_facts_summary AS
SELECT 
  user_id,
  category,
  COUNT(*) as fact_count,
  AVG(confidence) as avg_confidence,
  MAX(created_at) as last_fact_added
FROM learned_facts
GROUP BY user_id, category;
