# JGD2024 平面直角座標系 WKT定義テンプレート
# 日本の平面直角座標系1-19系のパラメータ

function Get-JGD2024PlaneWKT {
    param([int]$zone)

    # 各系の中央経線と原点緯度
    $params = @{
        1  = @{ lat = 33.0; lon = 129.5 }           # 1系: 長崎県、鹿児島県の一部
        2  = @{ lat = 33.0; lon = 131.0 }           # 2系: 福岡県、佐賀県、熊本県、大分県、宮崎県、鹿児島県の一部
        3  = @{ lat = 36.0; lon = 132.166666666667 } # 3系: 山口県、島根県、広島県
        4  = @{ lat = 33.0; lon = 133.5 }           # 4系: 香川県、愛媛県、徳島県、高知県
        5  = @{ lat = 36.0; lon = 134.333333333333 } # 5系: 兵庫県、鳥取県、岡山県
        6  = @{ lat = 36.0; lon = 136.0 }           # 6系: 京都府、大阪府、福井県、滋賀県、三重県、奈良県、和歌山県
        7  = @{ lat = 36.0; lon = 137.166666666667 } # 7系: 石川県、富山県、岐阜県、愛知県
        8  = @{ lat = 36.0; lon = 138.5 }           # 8系: 新潟県、長野県、山梨県、静岡県
        9  = @{ lat = 36.0; lon = 139.833333333333 } # 9系: 福島県、栃木県、茨城県、埼玉県、千葉県、群馬県、神奈川県
        10 = @{ lat = 40.0; lon = 140.833333333333 } # 10系: 青森県、秋田県、山形県、岩手県、宮城県
        11 = @{ lat = 44.0; lon = 140.25 }          # 11系: 小樽市、函館市、伊達市を除く北海道
        12 = @{ lat = 44.0; lon = 142.25 }          # 12系: 北見市、網走市、紋別市、北海道の一部
        13 = @{ lat = 44.0; lon = 144.25 }          # 13系: 釧路市、帯広市、北海道の一部
        14 = @{ lat = 26.0; lon = 142.0 }           # 14系: 東京都（島しょ部）
        15 = @{ lat = 26.0; lon = 127.5 }           # 15系: 沖縄県
        16 = @{ lat = 26.0; lon = 124.0 }           # 16系: 沖縄県（先島諸島）
        17 = @{ lat = 26.0; lon = 131.0 }           # 17系: 沖縄県（大東諸島）
        18 = @{ lat = 20.0; lon = 136.0 }           # 18系: 小笠原諸島
        19 = @{ lat = 26.0; lon = 154.0 }           # 19系: 南鳥島
    }

    if (-not $params.ContainsKey($zone)) {
        return $null
    }

    $p = $params[$zone]

    return "PROJCS[`"JGD2024_Japan_Zone_$zone`",GEOGCS[`"JGD2024`",DATUM[`"Japanese_Geodetic_Datum_2024`",SPHEROID[`"GRS_1980`",6378137.0,298.257222101]],PRIMEM[`"Greenwich`",0.0],UNIT[`"Degree`",0.0174532925199433]],PROJECTION[`"Transverse_Mercator`"],PARAMETER[`"False_Easting`",0.0],PARAMETER[`"False_Northing`",0.0],PARAMETER[`"Central_Meridian`",$($p.lon)],PARAMETER[`"Scale_Factor`",0.9999],PARAMETER[`"Latitude_Of_Origin`",$($p.lat)],UNIT[`"Meter`",1.0]]"
}

function Get-JGD2024UTMWKT {
    param([int]$zone)

    # UTMゾーンの中央経線計算: (zone * 6) - 183
    $centralMeridian = ($zone * 6) - 183

    # 日本で使用されるUTMゾーン51-56の範囲チェック
    if ($zone -lt 51 -or $zone -gt 56) {
        return $null
    }

    return "PROJCS[`"JGD_2024_UTM_Zone_${zone}N`",GEOGCS[`"GCS_JGD_2024`",DATUM[`"D_JGD_2024`",SPHEROID[`"GRS_1980`",6378137.0,298.257222101]],PRIMEM[`"Greenwich`",0.0],UNIT[`"Degree`",0.0174532925199433]],PROJECTION[`"Transverse_Mercator`"],PARAMETER[`"False_Easting`",500000.0],PARAMETER[`"False_Northing`",0.0],PARAMETER[`"Central_Meridian`",$centralMeridian.0],PARAMETER[`"Scale_Factor`",0.9996],PARAMETER[`"Latitude_Of_Origin`",0.0],UNIT[`"Meter`",1.0]]"
}

# テスト例
# Get-JGD2024PlaneWKT -zone 9  # 平面直角座標系9系
# Get-JGD2024UTMWKT -zone 51   # UTM51N