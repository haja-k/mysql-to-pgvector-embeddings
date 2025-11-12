DROP TABLE genie_documents;

CREATE TABLE genie_documents (
    id SERIAL PRIMARY KEY,
    question TEXT NOT NULL,
    answer TEXT,
    link TEXT,
    date TIMESTAMP,
    genie_uniqueid TEXT,
    full_embedding VECTOR(4096)
);

-- Create indexes for vector search
CREATE INDEX ON genie_documents USING ivfflat (full_embedding vector_cosine_ops);
ALTER TABLE genie_documents ADD CONSTRAINT unique_question UNIQUE (question);

-- Grant permissions to user
GRANT SELECT, INSERT, UPDATE ON genie_documents TO sainschat_user;
GRANT ALL ON SEQUENCE genie_documents_id_seq TO sainschat_user;
