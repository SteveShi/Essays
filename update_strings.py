import json
import sys

def main():
    file_path = 'Resources/Localizable.xcstrings'
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except Exception as e:
        print(f"Error reading file: {e}")
        sys.exit(1)

    new_strings = {
        'AI Assistant': '闪念助手',
        'Summarize': '摘要',
        'Improve Writing': '润色改写',
        'Expand': '扩展内容',
        'Generate Tags': '生成标签',
        'Related Ideas': '相关灵感',
        'Generate a brief summary': '生成简短摘要',
        'Polish grammar and clarity': '优化语法和表达',
        'Add more details and examples': '补充细节和示例',
        'Suggest relevant tags': '推荐相关标签',
        'Discover related topics': '发现相关话题',
        'Copy to Clipboard': '复制到剪贴板',
        'No memo selected': '未选择闪念',
        'AI assistant not initialized': 'AI 助手未初始化',
        'AI generation failed: %@': 'AI 生成失败：%@',
        'AI': 'AI',
        'Enable AI Features': '启用 AI 功能',
        'Apple Intelligence': 'Apple 智能',
        'Translation': '翻译',
        'Target Translation Language': '翻译目标语言',
        'Auto-detect': '自动检测',
        'Status': '状态',
        'AI Ready': 'AI 就绪',
        'AI features use Apple Intelligence on-device processing and will not send any data to the cloud.': 'AI 功能使用 Apple 智能进行端侧处理，不会发送任何数据到云端。'
    }

    count = 0
    for key, zh in new_strings.items():
        if key not in data['strings']:
            data['strings'][key] = {
                'localizations': {
                    'en': {'stringUnit': {'state': 'translated', 'value': key}},
                    'zh-Hans': {'stringUnit': {'state': 'translated', 'value': zh}}
                }
            }
            count += 1
        else:
            if 'localizations' not in data['strings'][key]:
                data['strings'][key]['localizations'] = {}
            if 'zh-Hans' not in data['strings'][key]['localizations']:
                data['strings'][key]['localizations']['zh-Hans'] = {
                    'stringUnit': {'state': 'translated', 'value': zh}
                }
                count += 1
            else:
                data['strings'][key]['localizations']['zh-Hans']['stringUnit']['value'] = zh

    with open(file_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    
    print(f"Done! Added/Updated {count} translations")

if __name__ == "__main__":
    main()
