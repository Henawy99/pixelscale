'use client';
import { useRef, useState } from 'react';

interface Props {
  label: string;
  required?: boolean;
  accept?: string;
  multiple?: boolean;
  onChange: (files: File[]) => void;
}

export default function FileUpload({ label, required, accept = 'image/*,.pdf', multiple = true, onChange }: Props) {
  const inputRef = useRef<HTMLInputElement>(null);
  const [files, setFiles] = useState<File[]>([]);

  const handleFiles = (newFiles: FileList | null) => {
    if (!newFiles) return;
    const arr = [...files, ...Array.from(newFiles)];
    setFiles(arr);
    onChange(arr);
  };

  const remove = (idx: number) => {
    const arr = files.filter((_, i) => i !== idx);
    setFiles(arr);
    onChange(arr);
  };

  return (
    <div className="form-group">
      <label>{label}{required && <span className="required">*</span>}</label>
      <div
        className={`file-upload-area ${files.length > 0 ? 'has-files' : ''}`}
        onClick={() => inputRef.current?.click()}
        onDragOver={(e) => { e.preventDefault(); e.stopPropagation(); }}
        onDrop={(e) => { e.preventDefault(); handleFiles(e.dataTransfer.files); }}
      >
        <div className="file-upload-icon">📎</div>
        <div className="file-upload-text">
          <strong>Dateien auswählen</strong> oder hierher ziehen
        </div>
        <input
          ref={inputRef}
          type="file"
          accept={accept}
          multiple={multiple}
          style={{ display: 'none' }}
          onChange={(e) => handleFiles(e.target.files)}
        />
      </div>
      {files.length > 0 && (
        <div className="file-list">
          {files.map((f, i) => (
            <div key={i} className="file-item">
              <span>📄 {f.name} ({(f.size / 1024).toFixed(0)} KB)</span>
              <button type="button" className="file-remove" onClick={(e) => { e.stopPropagation(); remove(i); }}>✕</button>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
