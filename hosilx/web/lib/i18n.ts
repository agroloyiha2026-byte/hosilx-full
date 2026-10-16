export type Lang = "uz" | "ru" | "en";
export const LANGS: Lang[] = ["uz", "ru", "en"];

export const dict: Record<Lang, Record<string, string>> = {
  uz: {
    nav_market: "Bozor", nav_wh: "Omborlar", nav_ai: "AI yordamchi", login: "Kirish",
    hero_title: "Hosilingizni soting, xaridorlarni toping va fermerlik ishlaringizni boshqaring",
    hero_sub: "Fermerlar, xaridorlar va omborlar uchun yagona agroplatforma.",
    search_ph: "Mahsulot qidiring: pomidor, bug‘doy...", search: "Qidirish",
    go_market: "Bozorga o‘tish", find_wh: "Ombor topish", ask_ai: "AI’dan so‘rash",
    f1_t: "Mahsulotni soting", f1_d: "E’lon joylang va xaridor bilan to‘g‘ridan-to‘g‘ri kelishing.",
    f2_t: "Ombor toping", f2_d: "Sig‘im, narx va sharoitlarni solishtiring.",
    f3_t: "AI agro maslahat", f3_d: "Ekin va parvarish bo‘yicha savollarga yordam.",
    f4_t: "Vazifa va moliya", f4_d: "Ishlar, daromad va xarajatlarni bir joyda kuzating.",
    all: "Barchasi", cat_fruit: "Mevalar", cat_vegetable: "Sabzavotlar", cat_grain: "Don",
    cat_dairy: "Sut mahsulotlari", cat_other: "Boshqa",
    loading: "Yuklanmoqda...", error: "Ma’lumotni yuklab bo‘lmadi. Internetni tekshirib, qayta urinib ko‘ring.",
    retry: "Qayta urinish", empty_market: "Hozircha e’lonlar yo‘q. Birinchi bo‘lib mahsulot joylang!",
    add_product: "Mahsulot qo‘shish", details: "Batafsil", available: "Mavjud",
  },
  ru: {
    nav_market: "Рынок", nav_wh: "Склады", nav_ai: "AI-помощник", login: "Войти",
    hero_title: "Продавайте урожай, находите покупателей и управляйте фермерскими делами",
    hero_sub: "Единая агроплатформа для фермеров, покупателей и складов.",
    search_ph: "Найти продукт: помидоры, пшеница...", search: "Найти",
    go_market: "Перейти на рынок", find_wh: "Найти склад", ask_ai: "Спросить AI",
    f1_t: "Продавайте продукцию", f1_d: "Разместите объявление и договоритесь с покупателем напрямую.",
    f2_t: "Найдите склад", f2_d: "Сравнивайте вместимость, цены и условия.",
    f3_t: "AI-агроконсультант", f3_d: "Помощь по вопросам культур и ухода.",
    f4_t: "Задачи и финансы", f4_d: "Работы, доходы и расходы в одном месте.",
    all: "Все", cat_fruit: "Фрукты", cat_vegetable: "Овощи", cat_grain: "Зерно",
    cat_dairy: "Молочные продукты", cat_other: "Другое",
    loading: "Загрузка...", error: "Не удалось загрузить данные. Проверьте интернет и повторите.",
    retry: "Повторить", empty_market: "Пока нет объявлений. Разместите первое!",
    add_product: "Добавить продукт", details: "Подробнее", available: "В наличии",
  },
  en: {
    nav_market: "Market", nav_wh: "Warehouses", nav_ai: "AI assistant", login: "Log in",
    hero_title: "Sell your harvest, find buyers and manage your farm work",
    hero_sub: "One agro platform for farmers, buyers and warehouses.",
    search_ph: "Search a product: tomato, wheat...", search: "Search",
    go_market: "Go to market", find_wh: "Find a warehouse", ask_ai: "Ask AI",
    f1_t: "Sell your produce", f1_d: "Post a listing and agree with buyers directly.",
    f2_t: "Find storage", f2_d: "Compare capacity, price and conditions.",
    f3_t: "AI agro advice", f3_d: "Help with crops and plant care questions.",
    f4_t: "Tasks & finance", f4_d: "Track work, income and expenses in one place.",
    all: "All", cat_fruit: "Fruit", cat_vegetable: "Vegetables", cat_grain: "Grain",
    cat_dairy: "Dairy", cat_other: "Other",
    loading: "Loading...", error: "Could not load data. Check your connection and retry.",
    retry: "Retry", empty_market: "No listings yet. Be the first to post!",
    add_product: "Add product", details: "Details", available: "Available",
  },
};

import { extra } from "./i18n_extra";
for (const l of LANGS) Object.assign(dict[l], extra[l]);
import { extra2 } from "./i18n_extra2";
for (const l of LANGS) Object.assign(dict[l], extra2[l]);
import { extra3 } from "./i18n_extra3";
for (const l of LANGS) Object.assign(dict[l], extra3[l]);
import { extra4 } from "./i18n_extra4";
for (const l of LANGS) Object.assign(dict[l], extra4[l]);
import { extra5 } from "./i18n_extra5";
for (const l of LANGS) Object.assign(dict[l], extra5[l]);
