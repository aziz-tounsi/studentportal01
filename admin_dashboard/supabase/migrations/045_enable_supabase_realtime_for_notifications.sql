-- Enable Realtime publication for tables requiring instant notifications & updates
DO $$
BEGIN
  -- Add announcements_global to supabase_realtime if not already added
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'announcements_global'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE announcements_global;
  END IF;

  -- Add announcements_class to supabase_realtime if not already added
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'announcements_class'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE announcements_class;
  END IF;

  -- Add suggestions to supabase_realtime if not already added
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'suggestions'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE suggestions;
  END IF;

  -- Add suggestion_replies to supabase_realtime if not already added
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'suggestion_replies'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE suggestion_replies;
  END IF;

  -- Add documents to supabase_realtime if not already added
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'documents'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE documents;
  END IF;
END $$;

-- Enable REPLICA IDENTITY FULL for these tables so payloads contain all row columns
ALTER TABLE announcements_global REPLICA IDENTITY FULL;
ALTER TABLE announcements_class REPLICA IDENTITY FULL;
ALTER TABLE suggestions REPLICA IDENTITY FULL;
ALTER TABLE suggestion_replies REPLICA IDENTITY FULL;
ALTER TABLE documents REPLICA IDENTITY FULL;
