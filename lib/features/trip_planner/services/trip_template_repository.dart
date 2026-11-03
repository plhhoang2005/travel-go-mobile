import '../models/trip_template.dart';

class TripTemplateRepository {
  List<TripTemplate> getCuratedTemplates() {
    return const [
      TripTemplate(
        id: 'da-lat-3d',
        title: 'Đà Lạt 3N2Đ: Thành phố ngàn hoa & Cà phê chill',
        destinationId: 'da-lat',
        destinationName: 'Đà Lạt',
        numDays: 3,
        estimatedBudgetVnd: 3500000,
        tagline: 'Săn mây đồi chè Cầu Đất, dạo Hồ Xuân Hương và chill quán cà phê',
        tags: ['Nghỉ dưỡng', 'Check-in', 'Cà phê', 'Ẩm thực'],
        imageUrl: 'https://images.unsplash.com/photo-1588668214407-6ea9a6d8c272?w=800',
        days: [
          TemplateDay(
            dayNumber: 1,
            title: 'Khám phá trung tâm & Chợ đêm Đà Lạt',
            activities: [
              TemplateActivity(
                title: 'Check-in Quảng trường Lâm Viên & Hồ Xuân Hương',
                placeId: 'lam-vien-square',
                startMinute: 540, // 09:00
                endMinute: 660,   // 11:00
                notes: 'Chụp ảnh nụ hoa Atiso và hoa dã quỳ khổng lồ',
              ),
              TemplateActivity(
                title: 'Thưởng thức bánh căn Lệ Yersin',
                startMinute: 690, // 11:30
                endMinute: 780,   // 13:00
                notes: 'Bánh căn trứng cút lòng đào & xíu mại nóng hổi',
              ),
              TemplateActivity(
                title: 'Dạo chơi & Ăn vặt Chợ đêm Đà Lạt',
                startMinute: 1140, // 19:00
                endMinute: 1290,  // 21:30
                notes: 'Bánh tráng nướng, sữa đậu nành nóng và dâu lắc',
              ),
            ],
          ),
          TemplateDay(
            dayNumber: 2,
            title: 'Săn mây Cầu Đất & Vườn hoa cẩm tú cầu',
            activities: [
              TemplateActivity(
                title: 'Đón bình minh & săn mây Đồi chè Cầu Đất',
                startMinute: 330, // 05:30
                endMinute: 480,  // 08:00
                notes: 'Ngắm tuabin gió và thung lũng mây bồng bềnh',
              ),
              TemplateActivity(
                title: 'Check-in Cánh đồng hoa Cẩm Tú Cầu Trại Mát',
                startMinute: 540, // 09:00
                endMinute: 660,  // 11:00
                notes: 'Vườn hoa rực rỡ sắc màu giữa sườn đồi',
              ),
              TemplateActivity(
                title: 'Chill cà phê hoàng hôn sườn đồi',
                startMinute: 990, // 16:30
                endMinute: 1110, // 18:30
                notes: 'Ngắm hoàng hôn buông xuống thung lũng đèn lồng',
              ),
            ],
          ),
          TemplateDay(
            dayNumber: 3,
            title: 'Chùa Linh Phước & Mua quà lưu niệm',
            activities: [
              TemplateActivity(
                title: 'Chiêm bái Chùa Ve Chai (Chùa Linh Phước)',
                startMinute: 540, // 09:00
                endMinute: 660,  // 11:00
                notes: 'Kiến trúc khảm gốm sứ độc đáo bậc nhất Việt Nam',
              ),
              TemplateActivity(
                title: 'Mua mứt và atiso làm quà tại L’angfarm',
                startMinute: 840, // 14:00
                endMinute: 930,  // 15:30
                notes: 'Đặc sản Đà Lạt chính hãng làm quà cho người thân',
              ),
            ],
          ),
        ],
      ),
      TripTemplate(
        id: 'ha-noi-2d',
        title: 'Hà Nội 2N1Đ: Tinh hoa ẩm thực & 36 Phố phường',
        destinationId: 'ha-noi',
        destinationName: 'Hà Nội',
        numDays: 2,
        estimatedBudgetVnd: 2000000,
        tagline: 'Phở Thìn Lò Đúc, Cà phê Trứng Giảng và dạo quanh Hồ Gươm',
        tags: ['Văn hóa', 'Ẩm thực', 'Phố cổ', 'Di tích'],
        imageUrl: 'https://images.unsplash.com/photo-1509062522246-3755977927d7?w=800',
        days: [
          TemplateDay(
            dayNumber: 1,
            title: 'Hồ Hoàn Kiếm, Văn Miếu & Phố cổ Hà Nội',
            activities: [
              TemplateActivity(
                title: 'Ăn phở bò Bát Đàn & Thưởng thức cà phê Trứng Giảng',
                startMinute: 450, // 07:30
                endMinute: 540,  // 09:00
                notes: 'Hương vị phở gia truyền và tách cà phê trứng béo ngậy',
              ),
              TemplateActivity(
                title: 'Dạo quanh Hồ Gươm & Thăm Đền Ngọc Sơn',
                startMinute: 570, // 09:30
                endMinute: 690,  // 11:30
                notes: 'Cầu Thê Húc đỏ son, Tháp Bút và Đền Ngọc Sơn cổ kính',
              ),
              TemplateActivity(
                title: 'Thăm Văn Miếu - Quốc Tử Giám',
                startMinute: 870, // 14:30
                endMinute: 990,  // 16:30
                notes: 'Trường đại học đầu tiên của Việt Nam và bia Tiến sĩ',
              ),
              TemplateActivity(
                title: 'Khám phá ẩm thực phố Tạ Hiện về đêm',
                startMinute: 1170, // 19:30
                endMinute: 1320,  // 22:00
                notes: 'Không khí nhộn nhịp, nem chua rán và bia tươi phố cổ',
              ),
            ],
          ),
          TemplateDay(
            dayNumber: 2,
            title: 'Lăng Bác, Hồ Tây & Mua sắm lưu niệm',
            activities: [
              TemplateActivity(
                title: 'Viếng Lăng Chủ tịch Hồ Chí Minh & Chùa Một Cột',
                startMinute: 480, // 08:00
                endMinute: 630,  // 10:30
                notes: 'Quảng trường Ba Đình trang nghiêm và kiến trúc Chùa Một Cột',
              ),
              TemplateActivity(
                title: 'Ăn bánh tôm Hồ Tây & Kem Tràng Tiền',
                startMinute: 720, // 12:00
                endMinute: 840,  // 14:00
                notes: 'Bánh tôm giòn rụm bên mặt nước Hồ Tây thơ mộng',
              ),
            ],
          ),
        ],
      ),
      TripTemplate(
        id: 'da-nang-4d',
        title: 'Đà Nẵng - Hội An 4N3Đ: Cầu Vàng & Phố cổ đèn lồng',
        destinationId: 'da-nang',
        destinationName: 'Đà Nẵng',
        numDays: 4,
        estimatedBudgetVnd: 5500000,
        tagline: 'Bà Nà Hills, tắm biển Mỹ Khê và thả đèn hoa đăng sông Hoài',
        tags: ['Biển đảo', 'Di sản', 'Check-in', 'Gia đình'],
        imageUrl: 'https://images.unsplash.com/photo-1559592413-7cec4d0cae2b?w=800',
        days: [
          TemplateDay(
            dayNumber: 1,
            title: 'Check-in Đà Nẵng & Tắm biển Mỹ Khê',
            activities: [
              TemplateActivity(
                title: 'Tắm biển & Dạo bãi cát trắng Mỹ Khê',
                startMinute: 900, // 15:00
                endMinute: 1050, // 17:30
                notes: 'Bãi biển nằm trong top đẹp nhất hành tinh',
              ),
              TemplateActivity(
                title: 'Ngắm Cầu Rồng phun lửa và phun nước',
                startMinute: 1230, // 20:30
                endMinute: 1320,  // 22:00
                notes: 'Biểu tượng hiện đại và rực rỡ của thành phố Đà Nẵng',
              ),
            ],
          ),
          TemplateDay(
            dayNumber: 2,
            title: 'Vui chơi trọn ngày tại Sun World Bà Nà Hills',
            activities: [
              TemplateActivity(
                title: 'Check-in Cầu Vàng Bàn Tay Khổng Lồ',
                startMinute: 510, // 08:30
                endMinute: 660,  // 11:00
                notes: 'Kỳ quan kiến trúc vươn giữa mây trời',
              ),
              TemplateActivity(
                title: 'Khám phá Làng Pháp & Lâu đài Mặt Trăng',
                startMinute: 720, // 12:00
                endMinute: 960,  // 16:00
                notes: 'Không gian châu Âu cổ tích trên đỉnh núi Chúa',
              ),
            ],
          ),
          TemplateDay(
            dayNumber: 3,
            title: 'Khám phá Di sản Phố cổ Hội An',
            activities: [
              TemplateActivity(
                title: 'Thăm Chùa Cầu & Nhà cổ Tấn Ký',
                startMinute: 870, // 14:30
                endMinute: 1020, // 17:00
                notes: 'Kiến trúc giao thoa Việt - Nhật - Hoa trăm năm',
              ),
              TemplateActivity(
                title: 'Thả đèn hoa đăng trên dòng sông Hoài thơ mộng',
                startMinute: 1110, // 18:30
                endMinute: 1260,  // 21:00
                notes: 'Ánh đèn lồng lung linh huyền ảo khắp các con phố',
              ),
            ],
          ),
          TemplateDay(
            dayNumber: 4,
            title: 'Bán đảo Sơn Trà & Chùa Linh Ứng',
            activities: [
              TemplateActivity(
                title: 'Chiêm bái Tượng Phật Bà Quan Âm Chùa Linh Ứng',
                startMinute: 510, // 08:30
                endMinute: 630,  // 10:30
                notes: 'Tượng Phật cao nhất Việt Nam nhìn ra biển Đông bao la',
              ),
              TemplateActivity(
                title: 'Thưởng thức bánh tráng cuốn thịt heo hai đầu da',
                startMinute: 690, // 11:30
                endMinute: 780,  // 13:00
                notes: 'Món ăn đặc sản trứ danh xứ Quảng trước khi ra sân bay',
              ),
            ],
          ),
        ],
      ),
      TripTemplate(
        id: 'sa-pa-3d',
        title: 'Sa Pa 3N2Đ: Săn mây Fansipan & Bản làng Cát Cát',
        destinationId: 'sa-pa',
        destinationName: 'Sa Pa',
        numDays: 3,
        estimatedBudgetVnd: 4000000,
        tagline: 'Chinh phục nóc nhà Đông Dương, ngắm ruộng bậc thang Mường Hoa',
        tags: ['Thiên nhiên', 'Trekking', 'Văn hóa bản địa'],
        imageUrl: 'https://images.unsplash.com/photo-1528127269322-539801943592?w=800',
        days: [
          TemplateDay(
            dayNumber: 1,
            title: 'Thị trấn Sa Pa & Nhà thờ đá cổ kính',
            activities: [
              TemplateActivity(
                title: 'Dạo quanh Nhà thờ Đá Sa Pa & Quảng trường',
                startMinute: 570, // 09:30
                endMinute: 690,  // 11:30
                notes: 'Kiến trúc đá thời Pháp cổ kính giữa màn sương mù',
              ),
              TemplateActivity(
                title: 'Khám phá Bản Cát Cát của người H’Mông',
                startMinute: 870, // 14:30
                endMinute: 1050, // 17:30
                notes: 'Guồng nước khổng lồ, suối Hoa và cầu treo mộng mơ',
              ),
            ],
          ),
          TemplateDay(
            dayNumber: 2,
            title: 'Chinh phục Đỉnh Fansipan 3.143m',
            activities: [
              TemplateActivity(
                title: 'Đi cáp treo & Chạm tay cột mốc Nóc nhà Đông Dương',
                startMinute: 480, // 08:00
                endMinute: 720,  // 12:00
                notes: 'Biển mây kỳ vĩ và quần thể tâm linh trên đỉnh Fansipan',
              ),
              TemplateActivity(
                title: 'Tắm lá thuốc người Dao Đỏ & Ăn lẩu cá hồi',
                startMinute: 1080, // 18:00
                endMinute: 1230,  // 20:30
                notes: 'Phục hồi thể lực và thưởng thức ẩm thực đặc trưng Tây Bắc',
              ),
            ],
          ),
          TemplateDay(
            dayNumber: 3,
            title: 'Đèo Ô Quy Hồ & Thác Bạc',
            activities: [
              TemplateActivity(
                title: 'Check-in Đèo Ô Quy Hồ - Tứ đại đỉnh đèo miền Bắc',
                startMinute: 510, // 08:30
                endMinute: 660,  // 11:00
                notes: 'Tầm nhìn ngoạn mục ôm trọn dãy Hoàng Liên Sơn hùng vĩ',
              ),
            ],
          ),
        ],
      ),
    ];
  }
}
