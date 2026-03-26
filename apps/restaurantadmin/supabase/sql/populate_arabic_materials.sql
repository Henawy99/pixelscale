-- Populate Arabic translations for common materials
-- This script updates existing materials with Arabic names

-- Update common ingredients with Arabic translations
UPDATE public.material 
SET arabic_name = 'دقيق'
WHERE LOWER(name) = 'flour' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'سكر'
WHERE LOWER(name) = 'sugar' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'ملح'
WHERE LOWER(name) = 'salt' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'فلفل'
WHERE LOWER(name) = 'pepper' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'زيت'
WHERE LOWER(name) = 'oil' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'زبدة'
WHERE LOWER(name) = 'butter' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'حليب'
WHERE LOWER(name) = 'milk' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'بيض'
WHERE LOWER(name) = 'eggs' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'جبن'
WHERE LOWER(name) = 'cheese' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'طماطم'
WHERE LOWER(name) = 'tomato' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'بصل'
WHERE LOWER(name) = 'onion' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'ثوم'
WHERE LOWER(name) = 'garlic' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'دجاج'
WHERE LOWER(name) = 'chicken' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'لحم بقري'
WHERE LOWER(name) = 'beef' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'سمك'
WHERE LOWER(name) = 'fish' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'أرز'
WHERE LOWER(name) = 'rice' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'معكرونة'
WHERE LOWER(name) = 'pasta' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'خبز'
WHERE LOWER(name) = 'bread' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'خس'
WHERE LOWER(name) = 'lettuce' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'خيار'
WHERE LOWER(name) = 'cucumber' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'جزر'
WHERE LOWER(name) = 'carrot' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'بطاطس'
WHERE LOWER(name) = 'potato' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'ليمون'
WHERE LOWER(name) = 'lemon' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'ليمون حامض'
WHERE LOWER(name) = 'lime' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'أعشاب'
WHERE LOWER(name) = 'herbs' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'توابل'
WHERE LOWER(name) = 'spices' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'صلصة'
WHERE LOWER(name) = 'sauce' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'كاتشب'
WHERE LOWER(name) = 'ketchup' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'مايونيز'
WHERE LOWER(name) = 'mayonnaise' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'خردل'
WHERE LOWER(name) = 'mustard' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'خل'
WHERE LOWER(name) = 'vinegar' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'عسل'
WHERE LOWER(name) = 'honey' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'فانيليا'
WHERE LOWER(name) = 'vanilla' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'قرفة'
WHERE LOWER(name) = 'cinnamon' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'زنجبيل'
WHERE LOWER(name) = 'ginger' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'ريحان'
WHERE LOWER(name) = 'basil' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'أوريجانو'
WHERE LOWER(name) = 'oregano' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'زعتر'
WHERE LOWER(name) = 'thyme' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'إكليل الجبل'
WHERE LOWER(name) = 'rosemary' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'بقدونس'
WHERE LOWER(name) = 'parsley' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'كزبرة'
WHERE LOWER(name) = 'cilantro' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'نعناع'
WHERE LOWER(name) = 'mint' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'شبت'
WHERE LOWER(name) = 'dill' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'ورق الغار'
WHERE LOWER(name) = 'bay leaves' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'بابريكا'
WHERE LOWER(name) = 'paprika' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'كمون'
WHERE LOWER(name) = 'cumin' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'هيل'
WHERE LOWER(name) = 'cardamom' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'قرنفل'
WHERE LOWER(name) = 'cloves' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'جوزة الطيب'
WHERE LOWER(name) = 'nutmeg' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'بهارات مشكلة'
WHERE LOWER(name) = 'allspice' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'كركم'
WHERE LOWER(name) = 'turmeric' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'مسحوق الفلفل الحار'
WHERE LOWER(name) = 'chili powder' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'رقائق الفلفل الأحمر'
WHERE LOWER(name) = 'red pepper flakes' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'فلفل أسود'
WHERE LOWER(name) = 'black pepper' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'فلفل أبيض'
WHERE LOWER(name) = 'white pepper' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'ملح البحر'
WHERE LOWER(name) = 'sea salt' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'ملح كوشير'
WHERE LOWER(name) = 'kosher salt' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'زيت الزيتون'
WHERE LOWER(name) = 'olive oil' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'زيت نباتي'
WHERE LOWER(name) = 'vegetable oil' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'زيت جوز الهند'
WHERE LOWER(name) = 'coconut oil' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'زيت السمسم'
WHERE LOWER(name) = 'sesame oil' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'زيت عباد الشمس'
WHERE LOWER(name) = 'sunflower oil' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'زيت الكانولا'
WHERE LOWER(name) = 'canola oil' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'زيت الذرة'
WHERE LOWER(name) = 'corn oil' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'زيت الفول السوداني'
WHERE LOWER(name) = 'peanut oil' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'صلصة الصويا'
WHERE LOWER(name) = 'soy sauce' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'صلصة ورشستر'
WHERE LOWER(name) = 'worcestershire sauce' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'صلصة حارة'
WHERE LOWER(name) = 'hot sauce' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'صلصة الشواء'
WHERE LOWER(name) = 'barbecue sauce' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'صلصة ترياكي'
WHERE LOWER(name) = 'teriyaki sauce' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'بيستو'
WHERE LOWER(name) = 'pesto' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'صلصة بيستو'
WHERE LOWER(name) = 'pesto sauce' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'صلصة ألفريدو'
WHERE LOWER(name) = 'alfredo sauce' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'صلصة مارينارا'
WHERE LOWER(name) = 'marinara sauce' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'صلصة بولونيز'
WHERE LOWER(name) = 'bolognese sauce' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'صلصة كاربونارا'
WHERE LOWER(name) = 'carbonara sauce' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'صلصة البيتزا'
WHERE LOWER(name) = 'pizza sauce' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'صلصة إنشيلادا'
WHERE LOWER(name) = 'enchilada sauce' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'صلصة التاكو'
WHERE LOWER(name) = 'taco sauce' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'سالسا'
WHERE LOWER(name) = 'salsa' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'جواكامولي'
WHERE LOWER(name) = 'guacamole' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'حمص'
WHERE LOWER(name) = 'hummus' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'طحينة'
WHERE LOWER(name) = 'tahini' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'زبادي'
WHERE LOWER(name) = 'yogurt' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'كريمة حامضة'
WHERE LOWER(name) = 'sour cream' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'جبن كريمي'
WHERE LOWER(name) = 'cream cheese' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'موزاريلا'
WHERE LOWER(name) = 'mozzarella' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'شيدر'
WHERE LOWER(name) = 'cheddar' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'بارميزان'
WHERE LOWER(name) = 'parmesan' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'فيتا'
WHERE LOWER(name) = 'feta' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'ريكوتا'
WHERE LOWER(name) = 'ricotta' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'بروفولوني'
WHERE LOWER(name) = 'provolone' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'سويسري'
WHERE LOWER(name) = 'swiss' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'جودة'
WHERE LOWER(name) = 'gouda' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'بري'
WHERE LOWER(name) = 'brie' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'كامامبير'
WHERE LOWER(name) = 'camembert' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'جبن أزرق'
WHERE LOWER(name) = 'blue cheese' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'جبن الماعز'
WHERE LOWER(name) = 'goat cheese' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'جبن قريش'
WHERE LOWER(name) = 'cottage cheese' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'كريمة'
WHERE LOWER(name) = 'cream' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'كريمة ثقيلة'
WHERE LOWER(name) = 'heavy cream' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'نصف ونصف'
WHERE LOWER(name) = 'half and half' AND arabic_name IS NULL;

UPDATE public.material 
SET arabic_name = 'لبن رائب'
WHERE LOWER(name) = 'buttermilk' AND arabic_name IS NULL;

-- Show results
SELECT 
  name, 
  arabic_name,
  CASE 
    WHEN arabic_name IS NOT NULL THEN 'Translated'
    ELSE 'Not translated'
  END as status
FROM public.material 
WHERE arabic_name IS NOT NULL
ORDER BY name;
