import React, { useState, useRef, useEffect } from "react";
import HTMLFlipBook from "react-pageflip";
import { Document, Page, pdfjs } from "react-pdf";

// Setup pdf worker
pdfjs.GlobalWorkerOptions.workerSrc = new URL(
  "pdfjs-dist/build/pdf.worker.min.mjs",
  import.meta.url
).toString();

const PDFPage = React.forwardRef<HTMLDivElement, { pageNumber: number; width: number; height: number }>(
  ({ pageNumber, width, height }, ref) => {
    return (
      <div className="bg-white flex items-center justify-center overflow-hidden shadow-sm" ref={ref}>
        <Page 
          pageNumber={pageNumber} 
          width={width} 
          scale={1.02}
          className="w-full h-full flex items-center justify-center overflow-hidden [&_canvas]:!w-full [&_canvas]:!h-full [&_canvas]:!object-cover"
          renderAnnotationLayer={false} 
          renderTextLayer={false} 
          loading={<div className="animate-pulse bg-surface-2 w-full h-full" />}
        />
      </div>
    );
  }
);
PDFPage.displayName = "PDFPage";

export function Flipbook({ pdfUrl }: { pdfUrl: string }) {
  const [numPages, setNumPages] = useState<number>(0);
  const containerRef = useRef<HTMLDivElement>(null);
  const [dimensions, setDimensions] = useState({ width: 0, height: 0 });
  const [currentPage, setCurrentPage] = useState(0);
  const flipAudioRef = useRef<HTMLAudioElement | null>(null);

  useEffect(() => {
    if (typeof window !== 'undefined') {
      flipAudioRef.current = new Audio('/page-flip.wav');
      flipAudioRef.current.volume = 0.5;
    }
  }, []);

  function onDocumentLoadSuccess({ numPages }: { numPages: number }) {
    setNumPages(numPages);
  }

  // Responsive flipbook sizing based on container width
  useEffect(() => {
    const updateDimensions = () => {
        const winW = window.innerWidth;
        const winH = window.innerHeight;
        const isMobile = winW < 768;
        
        // Trừ không gian cho header và padding (khoảng 120px chiều cao, 40px chiều rộng)
        const usableWidth = Math.max(winW - 40, 200);
        const usableHeight = Math.max(winH - 120, 300);
        
        let pageW;
        if (isMobile) {
          // Mobile hiển thị 1 trang
          pageW = Math.min(usableWidth, usableHeight / 1.414);
        } else {
          // Desktop hiển thị 2 trang
          pageW = Math.min(usableWidth / 2, usableHeight / 1.414);
        }
        
        const pageH = Math.floor(pageW * 1.414);
        pageW = Math.floor(pageW);
        
        setDimensions({ width: pageW, height: pageH });
    };

    updateDimensions();
    window.addEventListener("resize", updateDimensions);
    return () => window.removeEventListener("resize", updateDimensions);
  }, []);

  const onPageFlip = (e: any) => {
    setCurrentPage(e.data);
    
    // Phát âm thanh lật giấy
    if (flipAudioRef.current) {
      flipAudioRef.current.currentTime = 0;
      flipAudioRef.current.play().catch(() => {
        // Bỏ qua lỗi nếu file chưa tồn tại hoặc bị trình duyệt chặn
      });
    }
  };

  const isMobile = typeof window !== 'undefined' ? window.innerWidth < 768 : true;
  
  // Tính toán vị trí dịch chuyển để căn giữa bìa sách
  let translateX = "0px";
  if (!isMobile && dimensions.width > 0) {
    if (currentPage === 0) {
      // Trang đầu (bìa trước) nằm ở bên phải của spread -> dịch sang trái
      translateX = `-${dimensions.width / 2}px`;
    } else if (currentPage === numPages - 1) {
      // Trang cuối (bìa sau) nằm ở bên trái của spread -> dịch sang phải
      translateX = `${dimensions.width / 2}px`;
    }
  }

  return (
    <div ref={containerRef} className="flex-1 w-full flex items-center justify-center overflow-hidden">
      {dimensions.width > 0 && (
        <Document 
          file={pdfUrl} 
          onLoadSuccess={onDocumentLoadSuccess}
          loading={<div className="text-ink-soft animate-pulse flex h-[400px] items-center justify-center">Đang tải PDF...</div>}
        >
          {numPages > 0 && (
            <div style={{ transform: `translateX(${translateX})`, transition: "transform 0.5s ease-in-out" }}>
              {/* @ts-ignore - react-pageflip types can be tricky */}
              <HTMLFlipBook 
                key={isMobile ? 'mobile' : 'desktop'}
                width={dimensions.width} 
                height={dimensions.height}
                size="fixed"
                minWidth={200}
                maxWidth={2000}
                minHeight={300}
                maxHeight={2828}
                showCover={true}
                usePortrait={isMobile}
                mobileScrollSupport={true}
                onFlip={onPageFlip}
                drawShadow={true}
              >
                {Array.from(new Array(numPages), (el, index) => (
                  <PDFPage 
                    key={`page_${index + 1}`} 
                    pageNumber={index + 1} 
                    width={dimensions.width}
                    height={dimensions.height}
                  />
                ))}
              </HTMLFlipBook>
            </div>
          )}
        </Document>
      )}
    </div>
  );
}
